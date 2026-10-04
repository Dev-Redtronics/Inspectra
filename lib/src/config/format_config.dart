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

import 'package:inspectra/src/config/generated_files.dart';
import 'package:inspectra/src/config/yaml_reader.dart';

/// The formatting check, done by `dart format`, the `format:` section.
final class FormatConfig {
  /// Creates the formatting settings.
  const FormatConfig({
    required this.enabled,
    required this.runOnBuild,
    required this.failOnFindings,
    required this.include,
    required this.exclude,
    required this.pageWidth,
  });

  /// Reads the settings from the `format:` section in [yaml].
  ///
  /// Returns the settings.
  ///
  /// Throws an `InspectraConfigException` for unknown keys or invalid
  /// values.
  factory FormatConfig.fromYaml(YamlReader yaml) {
    final config = FormatConfig(
      enabled: yaml.boolean('enabled', fallback: false),
      runOnBuild: yaml.boolean('run_on_build', fallback: false),
      failOnFindings: yaml.boolean('fail_on_findings', fallback: true),
      include: yaml.strings('include', fallback: defaultInclude),
      exclude: yaml.strings('exclude', fallback: defaultExclude),
      pageWidth: yaml.optionalInt('page_width', min: 1, max: 1000),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// The Dart files checked by default.
  static const defaultInclude = <String>['**.dart'];

  /// The files never checked by default: tool caches, build output and the
  /// output of the common code generators.
  static const defaultExclude = <String>[
    '**/.dart_tool/**',
    '**/build/**',
    ...generatedFiles,
  ];

  /// Whether the formatting is checked. Off by default.
  final bool enabled;

  /// Whether `dart run build_runner build` checks it too.
  final bool runOnBuild;

  /// Whether unformatted files fail the build or the command.
  final bool failOnFindings;

  /// Globs of the files to check, relative to the package root.
  final List<String> include;

  /// Globs of the files to leave out, relative to the package root.
  final List<String> exclude;

  /// The line length, or `null` for the `formatter: page_width` of
  /// `analysis_options.yaml`, and 80 without one.
  final int? pageWidth;
}
