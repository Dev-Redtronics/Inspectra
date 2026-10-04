/*
 * Copyright 2026 Redtronics
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:inspectra/src/archive/archive_entry.dart';
import 'package:inspectra/src/archive/archive_limits.dart';
import 'package:inspectra/src/archive/archive_reader.dart';
import 'package:inspectra/src/host/host_platform.dart';
import 'package:inspectra/src/io/process_outcome.dart';
import 'package:inspectra/src/io/process_runner.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/net/http_result.dart';
import 'package:inspectra/src/net/http_transport.dart';
import 'package:inspectra/src/trivy/trivy_release_asset.dart';
import 'package:path/path.dart' as p;

/// Downloads, verifies and installs a Trivy release.
///
/// Security properties:
///
/// * the archive's SHA-256 must match the entry of the official
///   `checksums.txt`; this check cannot be disabled, so an unverified binary
///   is never executed;
/// * only the `trivy` executable is taken from the archive, from its top
///   level, and the archive is read in memory within strict limits;
/// * the binary is written to a temporary file in the target directory,
///   made executable and atomically renamed into place, so concurrent CI
///   jobs never see a half written file.
final class TrivyInstaller {
  /// Creates an installer.
  const TrivyInstaller({
    required this.transport,
    required this.processRunner,
    required this.host,
  });

  /// The HTTP transport.
  final HttpTransport transport;

  /// Runs `chmod` on POSIX hosts.
  final ProcessRunner processRunner;

  /// The host platform.
  final HostPlatform host;

  /// The largest accepted Trivy archive: 512 MiB.
  static const int maxArchiveBytes = 512 * 1024 * 1024;

  /// Resolves the version behind the `latest` redirect at [latestUrl].
  ///
  /// GitHub answers `…/releases/latest` with a redirect to
  /// `…/releases/tag/v<version>`; reading the redirect avoids the rate
  /// limited GitHub API.
  ///
  /// Returns the bare version.
  ///
  /// Throws an [UnavailableException] when the redirect is missing.
  Future<String> resolveLatest(String latestUrl) async {
    final HttpResult result = await transport.get(
      Uri.parse(latestUrl),
      followRedirects: false,
      maxBytes: 1024 * 1024,
    );
    final String location = result.location?.toString() ?? '';
    final RegExpMatch? match = RegExp('/tag/v?([0-9][^/?#]*)')
        .firstMatch(location);
    final String? version = match?[1];
    if (version == null) {
      throw UnavailableException(
        'Could not determine the latest Trivy release from $latestUrl.',
      );
    }
    return version;
  }

  /// Downloads [asset] from [baseUrl] and installs its executable to
  /// [targetPath].
  ///
  /// Returns [targetPath].
  ///
  /// Throws an [UnavailableException] when the download or verification
  /// fails and an [InvalidInputException] when the archive is malformed.
  Future<String> install(
    TrivyReleaseAsset asset,
    String baseUrl,
    String targetPath,
  ) async {
    final String expected = await _expectedChecksum(asset, baseUrl);
    final Uri archiveUri = asset.archiveUri(baseUrl);
    final HttpResult download = await transport.get(
      archiveUri,
      maxBytes: maxArchiveBytes,
    );
    if (!download.isSuccess) {
      throw UnavailableException(
        'Downloading $archiveUri failed with HTTP ${download.statusCode}.',
      );
    }
    final actual = sha256.convert(download.bodyBytes).toString();
    if (actual != expected) {
      throw UnavailableException(
        'The Trivy archive ${asset.archiveName} does not match its published '
        'SHA-256 checksum (expected $expected, got $actual). It was '
        'discarded and not executed.',
      );
    }
    final Uint8List binary = _extractBinary(asset, download.bodyBytes);
    await _writeAtomically(binary, targetPath);
    return targetPath;
  }

  /// Downloads the checksum file and finds the entry of [asset].
  ///
  /// Returns the expected lower case SHA-256.
  ///
  /// Throws an [UnavailableException] when the file or entry is missing.
  Future<String> _expectedChecksum(
    TrivyReleaseAsset asset,
    String baseUrl,
  ) async {
    final Uri uri = asset.checksumsUri(baseUrl);
    final HttpResult result = await transport.get(uri, maxBytes: 1024 * 1024);
    if (!result.isSuccess) {
      throw UnavailableException(
        'Downloading $uri failed with HTTP ${result.statusCode}.',
      );
    }
    for (final String line in result.text.split('\n')) {
      final List<String> parts = line.trim().split(RegExp(r'\s+'));
      final bool matches =
          parts.length == 2 &&
          parts.last.replaceFirst('*', '') == asset.archiveName;
      if (matches) {
        return parts.first.toLowerCase();
      }
    }
    throw UnavailableException(
      '$uri does not list a checksum for ${asset.archiveName}.',
    );
  }

  /// Extracts the executable from the archive [bytes].
  ///
  /// Returns the executable's bytes.
  ///
  /// Throws an [InvalidInputException] when it is missing.
  Uint8List _extractBinary(TrivyReleaseAsset asset, Uint8List bytes) {
    const limits = ArchiveLimits(
      maxArchiveBytes: maxArchiveBytes,
      maxExtractedBytes: 2 * maxArchiveBytes,
      maxEntries: 1000,
    );
    const reader = ArchiveReader(limits);
    final List<ArchiveEntry> entries = asset.isZip
        ? reader.readZip(bytes)
        : reader.readTarGz(bytes);
    final ArchiveEntry? binary = entries
        .where((entry) => entry.isFile && entry.path == asset.binaryName)
        .firstOrNull;
    if (binary == null) {
      throw InvalidInputException(
        '${asset.archiveName} does not contain ${asset.binaryName}.',
      );
    }
    return binary.bytes;
  }

  /// Writes [bytes] to [targetPath] through a temporary file and an atomic
  /// rename.
  ///
  /// Throws an [UnavailableException] when the file cannot be written or
  /// made executable.
  Future<void> _writeAtomically(Uint8List bytes, String targetPath) async {
    final directory = Directory(p.dirname(targetPath));
    final String suffix = Random.secure().nextInt(1 << 32).toRadixString(16);
    final temporary = File(p.join(directory.path, '.trivy-$pid-$suffix.tmp'));
    try {
      directory.createSync(recursive: true);
      temporary.writeAsBytesSync(bytes, flush: true);
      await _makeExecutable(temporary.path);
      temporary.renameSync(targetPath);
    } on FileSystemException catch (error) {
      if (temporary.existsSync()) {
        temporary.deleteSync();
      }
      if (File(targetPath).existsSync()) {
        return;
      }
      throw UnavailableException(
        'Could not install Trivy to $targetPath: ${error.message}',
      );
    }
  }

  /// Marks [path] executable on POSIX hosts.
  ///
  /// Throws a [FileSystemException] when `chmod` fails.
  Future<void> _makeExecutable(String path) async {
    if (host.isWindows) {
      return;
    }
    final ProcessOutcome outcome = await processRunner.run('chmod', <String>[
      '755',
      path,
    ]);
    if (!outcome.succeeded) {
      throw FileSystemException('chmod failed: ${outcome.stderr}', path);
    }
  }
}
