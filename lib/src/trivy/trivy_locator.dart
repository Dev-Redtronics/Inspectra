/*
 * Copyright 2026 Davils
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

import 'dart:convert';
import 'dart:io';

import 'package:inspectra/src/io/environment.dart';
import 'package:inspectra/src/io/executable_resolver.dart';
import 'package:inspectra/src/io/process_outcome.dart';
import 'package:inspectra/src/io/process_runner.dart';
import 'package:inspectra/src/trivy/trivy_origin.dart';
import 'package:inspectra/src/trivy/trivy_provision.dart';
import 'package:path/path.dart' as p;

/// Finds Trivy executables that are already present on the machine.
final class TrivyLocator {
  /// Creates a locator.
  ///
  /// [installRoot] is the directory holding downloaded versions, one
  /// sub-directory per version.
  const TrivyLocator({
    required this.resolver,
    required this.processRunner,
    required this.environment,
    required this.installRoot,
    required this.binaryName,
    this.searchDirectories,
  });

  /// Resolves executables on the `PATH`.
  final ExecutableResolver resolver;

  /// Runs `trivy --version`.
  final ProcessRunner processRunner;

  /// The environment providing the home directory.
  final Environment environment;

  /// The directory holding downloaded Trivy versions.
  final String installRoot;

  /// The executable file name, `trivy` or `trivy.exe`.
  final String binaryName;

  /// The directories searched in addition to the `PATH`; `null` selects the
  /// well-known installation directories of package managers.
  final List<String>? searchDirectories;

  /// Checks the explicitly configured [executable].
  ///
  /// Returns the available executable, or `null` when it does not work.
  Future<TrivyAvailable?> configured(String executable) =>
      _probe(executable, TrivyOrigin.configured);

  /// Searches the `PATH` and well-known installation directories.
  ///
  /// Returns the first working executable, or `null`.
  Future<TrivyAvailable?> installed() async {
    final String? found = resolver.resolve(
      'trivy',
      extraDirectories: searchDirectories ?? _wellKnownDirectories(),
    );
    if (found == null) {
      return null;
    }
    return _probe(found, TrivyOrigin.installed);
  }

  /// Looks for a previously downloaded binary of [version].
  ///
  /// Returns the cached executable, or `null`.
  Future<TrivyAvailable?> cached(String version) {
    final String path = cachedPath(version);
    if (!File(path).existsSync()) {
      return Future<TrivyAvailable?>.value();
    }
    return _probe(path, TrivyOrigin.cached);
  }

  /// Returns the path where [version] is stored after download.
  String cachedPath(String version) => p.join(installRoot, version, binaryName);

  /// Finds the newest version present in the cache.
  ///
  /// Returns the version directory name, or `null` when the cache is empty.
  String? newestCachedVersion() {
    final root = Directory(installRoot);
    if (!root.existsSync()) {
      return null;
    }
    final List<String> versions =
        root
            .listSync()
            .whereType<Directory>()
            .map((directory) => p.basename(directory.path))
            .where(
              (name) =>
                  File(p.join(installRoot, name, binaryName)).existsSync(),
            )
            .toList()
          ..sort(_compareVersions);
    return versions.lastOrNull;
  }

  /// Runs [executable] to read its version.
  ///
  /// Returns the available executable, or `null` when it cannot run.
  Future<TrivyAvailable?> _probe(String executable, TrivyOrigin origin) async {
    try {
      final ProcessOutcome outcome = await processRunner.run(
        executable,
        const <String>['--version', '--format', 'json'],
        timeout: const Duration(seconds: 30),
      );
      if (!outcome.succeeded) {
        return null;
      }
      return TrivyAvailable(
        executable: executable,
        version: parseVersion(outcome.stdout) ?? 'unknown',
        origin: origin,
      );
    } on ProcessException {
      return null;
    }
  }

  /// Extracts the version from the output of `trivy --version`, accepting
  /// both the JSON and the plain text format.
  ///
  /// Returns the bare version, or `null` when none is found.
  static String? parseVersion(String output) {
    try {
      final Object? decoded = jsonDecode(output);
      if (decoded is Map<String, Object?> && decoded['Version'] is String) {
        final version = decoded['Version']! as String;
        return version.startsWith('v') ? version.substring(1) : version;
      }
    } on FormatException {
      final RegExpMatch? match = RegExp(r'Version:\s*v?(\S+)')
          .firstMatch(output);
      return match?[1];
    }
    return null;
  }

  /// The directories searched in addition to the `PATH`.
  ///
  /// Returns the existing well-known directories.
  List<String> _wellKnownDirectories() {
    final String? home = environment.homeDirectory;
    final String? localAppData = environment['LOCALAPPDATA'];
    return <String>[
      '/usr/local/bin',
      '/usr/bin',
      '/opt/homebrew/bin',
      '/home/linuxbrew/.linuxbrew/bin',
      '/snap/bin',
      if (home != null) p.join(home, '.local', 'bin'),
      if (home != null) p.join(home, 'bin'),
      if (home != null) p.join(home, 'scoop', 'shims'),
      if (localAppData != null) p.join(localAppData, 'Programs', 'trivy'),
      if (localAppData != null)
        p.join(localAppData, 'Microsoft', 'WinGet', 'Links'),
      r'C:\ProgramData\chocolatey\bin',
    ];
  }

  /// Compares two dotted version strings numerically.
  ///
  /// Returns a negative, zero or positive comparison result.
  static int _compareVersions(String a, String b) {
    final List<int> left = a
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    final List<int> right = b
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    for (var index = 0; index < 3; index++) {
      final int l = index < left.length ? left[index] : 0;
      final int r = index < right.length ? right[index] : 0;
      if (l != r) {
        return l.compareTo(r);
      }
    }
    return 0;
  }
}
