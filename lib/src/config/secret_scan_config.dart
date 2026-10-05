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

import 'package:inspectra/src/config/build_scan_config.dart';
import 'package:inspectra/src/config/scan_config.dart';
import 'package:inspectra/src/config/yaml_reader.dart';
import 'package:inspectra/src/model/severity.dart';

/// The secret scan, the `trivy.secret:` section.
final class SecretScanConfig extends BuildScanConfig {
  /// Creates the secret scan settings.
  const SecretScanConfig({
    required super.enabled,
    required super.runOnBuild,
    required super.failOnFindings,
    required super.severity,
    required this.config,
    required this.include,
    required this.exclude,
  });

  /// Reads the settings from the `trivy.secret:` section in [yaml].
  ///
  /// Returns the settings.
  ///
  /// Throws an `InspectraConfigException` for unknown keys or invalid
  /// values.
  factory SecretScanConfig.fromYaml(YamlReader yaml) {
    final config = SecretScanConfig(
      enabled: yaml.boolean('enabled', fallback: true),
      runOnBuild: yaml.boolean('run_on_build', fallback: true),
      failOnFindings: yaml.boolean('fail_on_findings', fallback: true),
      severity: ScanConfig.readSeverities(yaml, defaultSeverity),
      config: yaml.optionalPath('config'),
      include: yaml.strings('include', fallback: defaultInclude),
      exclude: yaml.strings('exclude', fallback: defaultExclude),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// The settings when nothing is configured.
  static const defaults = SecretScanConfig(
    enabled: true,
    runOnBuild: true,
    failOnFindings: true,
    severity: defaultSeverity,
    config: null,
    include: defaultInclude,
    exclude: defaultExclude,
  );

  /// The severities reported by default.
  static const defaultSeverity = <Severity>[
    Severity.critical,
    Severity.high,
    Severity.medium,
    Severity.low,
  ];

  /// The files scanned by default: the Dart sources and the configuration
  /// files a credential is actually pasted into.
  static const defaultInclude = <String>[
    '**.dart',
    '**.yaml',
    '**.yml',
    '**.json',
    '**.env',
    '**.properties',
  ];

  /// The files never scanned by default: generated output and tool caches.
  /// A secret there is a copy of one in a file this scan already reads.
  static const defaultExclude = <String>[
    '**/.dart_tool/**',
    '**/build/**',
    '**/.git/**',
  ];

  /// The Trivy secret configuration file, relative to the package root.
  ///
  /// When `null`, `trivy-secret.yaml` is used if it exists; a file that is
  /// named explicitly must exist.
  final String? config;

  /// Globs of the files to scan, relative to the package root.
  final List<String> include;

  /// Globs of the files to leave out, relative to the package root.
  final List<String> exclude;
}
