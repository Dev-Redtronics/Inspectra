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

import 'package:inspectra/src/config/hook_check.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/config/yaml_reader.dart';

/// The pre-commit hook, the `hook:` section of the configuration.
final class HookConfig {
  /// Creates the settings with the [checks] the hook runs.
  const HookConfig({this.checks = defaultChecks});

  /// Reads the settings from the `hook:` section in [yaml].
  ///
  /// Returns the settings.
  ///
  /// Throws an [InspectraConfigException] for unknown keys or checks.
  factory HookConfig.fromYaml(YamlReader yaml) {
    final config = HookConfig(
      checks: yaml.enums(
        'checks',
        fallback: defaultChecks,
        parse: (value) => HookCheck.values
            .where((check) => check.id == value.toLowerCase())
            .firstOrNull,
        options: <String>[for (final check in HookCheck.values) check.id],
        name: (check) => check.id,
        allowEmpty: true,
      ),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// The checks of the hook before it could be configured.
  static const defaultChecks = <HookCheck>[
    HookCheck.audit,
    HookCheck.typosquat,
  ];

  /// The checks the hook runs on the staged files.
  final List<HookCheck> checks;
}
