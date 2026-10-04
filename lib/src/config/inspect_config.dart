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

/// Settings of the package source inspector, the `inspect:` section of
/// `inspectra.yaml`.
final class InspectConfig {
  /// Creates inspector settings; every parameter has a safe default.
  const InspectConfig({
    this.failScore = 30,
    this.maxArchiveBytes = 64 * 1024 * 1024,
    this.maxExtractedBytes = 256 * 1024 * 1024,
    this.maxEntries = 20000,
    this.entropyExcludes = defaultEntropyExcludes,
    this.excludeDirectories = defaultExcludeDirectories,
    this.trustedHosts = const <String>[],
  });

  /// Top level package directories whose code never runs in a dependent
  /// project and is therefore not scanned for code patterns: tests,
  /// examples, benchmarks, documentation, maintainer tooling and prebuilt
  /// DevTools extensions. `lib/`, `bin/` and `hook/` are always scanned.
  static const List<String> defaultExcludeDirectories = <String>[
    'test',
    'integration_test',
    'example',
    'benchmark',
    'doc',
    'docs',
    'tool',
    'extension',
  ];

  /// File name suffixes of generated code that the entropy scanner skips.
  static const List<String> defaultEntropyExcludes = <String>[
    '.g.dart',
    '.freezed.dart',
    '.mocks.dart',
    '.pb.dart',
    '.gr.dart',
  ];

  /// The risk score from which a package counts as suspicious; `inspect`
  /// exits with `1` and `add` refuses to install at or above it.
  final int failScore;

  /// The maximum size of a downloaded package archive in bytes.
  final int maxArchiveBytes;

  /// The maximum total size of all extracted entries in bytes, which stops
  /// decompression bombs.
  final int maxExtractedBytes;

  /// The maximum number of archive entries.
  final int maxEntries;

  /// File name suffixes skipped by the entropy scanner.
  final List<String> entropyExcludes;

  /// Top level directories skipped by the regex and entropy scanners.
  ///
  /// Unicode and archive checks still cover every file, because hidden
  /// characters or traversal entries are suspicious wherever they appear.
  final List<String> excludeDirectories;

  /// Additional host names that the hard-coded URL rule treats as trusted,
  /// on top of the built-in Dart, Flutter and GitHub hosts.
  final List<String> trustedHosts;
}
