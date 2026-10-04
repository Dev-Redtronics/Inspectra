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

import 'package:inspectra/src/config/lint_level.dart';
import 'package:inspectra/src/config/yaml_reader.dart';

/// The static analysis check, done by `dart analyze`, the `lint:` section.
final class LintConfig {
  /// Creates the static analysis settings.
  const LintConfig({
    required this.enabled,
    required this.runOnBuild,
    required this.failOn,
  });

  /// Reads the settings from the `lint:` section in [yaml].
  ///
  /// Returns the settings.
  ///
  /// Throws an `InspectraConfigException` for unknown keys or invalid
  /// values.
  factory LintConfig.fromYaml(YamlReader yaml) {
    final config = LintConfig(
      enabled: yaml.boolean('enabled', fallback: false),
      runOnBuild: yaml.boolean('run_on_build', fallback: false),
      failOn: yaml.choice('fail_on', <String, LintLevel>{
        for (final level in LintLevel.values) level.name: level,
      }, fallback: LintLevel.info),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// Whether the package is analyzed. Off by default.
  final bool enabled;

  /// Whether `dart run build_runner build` analyzes it too.
  final bool runOnBuild;

  /// The lowest severity that fails the check.
  final LintLevel failOn;
}
