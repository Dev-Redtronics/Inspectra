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

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../model/inspectra_exception.dart';
import '../net/http_transport.dart';
import 'pub_version.dart';

/// Downloads package archives and proves their integrity.
///
/// The archive URL announced by the repository must use the repository's
/// scheme and point at the repository itself or at pub.dev, and the
/// downloaded bytes must match the published SHA-256 checksum. Otherwise the
/// download is rejected: inspecting bytes other than those pub would install
/// would make the whole inspection meaningless.
final class PackageArchiveDownloader {
  /// Creates a downloader for archives of the repository at [repositoryUrl]
  /// that are at most [maxBytes] large.
  const PackageArchiveDownloader({
    required this.transport,
    required this.repositoryUrl,
    required this.maxBytes,
  });

  /// The HTTP transport.
  final HttpTransport transport;

  /// The repository base URL.
  final String repositoryUrl;

  /// The maximum archive size.
  final int maxBytes;

  /// Hosts that serve archives of the public pub.dev repository.
  static const Set<String> _publicArchiveHosts = <String>{
    'pub.dev',
    'pub.dartlang.org',
  };

  /// Downloads the archive of [version] of package [name].
  ///
  /// Returns the verified archive bytes.
  ///
  /// Throws an [UnavailableException] when the archive cannot be downloaded,
  /// comes from an unexpected host or fails checksum verification.
  Future<Uint8List> download(String name, PubVersion version) async {
    final url = version.archiveUrl;
    if (url == null) {
      throw UnavailableException(
        'The repository did not announce an archive for $name '
        '${version.version}.',
      );
    }
    final uri = _validatedUri(url);
    final result = await transport.get(uri, maxBytes: maxBytes);
    if (!result.isSuccess) {
      throw UnavailableException(
        'Downloading $uri failed with HTTP ${result.statusCode}.',
      );
    }
    final expected = version.archiveSha256?.toLowerCase();
    final actual = sha256.convert(result.bodyBytes).toString();
    if (expected != null && expected != actual) {
      throw UnavailableException(
        'The archive of $name ${version.version} does not match its '
        'published SHA-256 checksum (expected $expected, got $actual). It '
        'was not inspected.',
      );
    }
    return result.bodyBytes;
  }

  /// Validates the announced archive [url].
  ///
  /// Returns the parsed URI.
  ///
  /// Throws an [UnavailableException] for unexpected schemes or hosts.
  Uri _validatedUri(String url) {
    final uri = Uri.parse(url);
    final repository = Uri.parse(repositoryUrl);
    final trustedHost =
        uri.host == repository.host || _publicArchiveHosts.contains(uri.host);
    final secure = uri.scheme == 'https' || uri.scheme == repository.scheme;
    if (!trustedHost || !secure) {
      throw UnavailableException(
        'The repository announced an archive at $url, outside of '
        '$repositoryUrl. It was not downloaded.',
      );
    }
    return uri;
  }
}
