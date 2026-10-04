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

import 'package:inspectra/src/config/yaml_reader.dart';

/// Settings of the typosquatting detector, the `typosquat:` section of
/// `inspectra.yaml`.
final class TyposquatConfig {
  /// Creates typosquat settings.
  const TyposquatConfig({
    this.allow = const <String>[],
    this.popular = const <String>[],
  });

  /// Reads the settings from the `typosquat:` section in [yaml].
  ///
  /// Returns the settings.
  ///
  /// Throws an `InspectraConfigException` for unknown keys or invalid
  /// values.
  factory TyposquatConfig.fromYaml(YamlReader yaml) {
    final config = TyposquatConfig(
      allow: yaml.strings('allow', fallback: const <String>[]),
      popular: yaml.strings('popular', fallback: const <String>[]),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// Package names that are never reported, for example internal packages
  /// whose names happen to resemble popular ones.
  final List<String> allow;

  /// Additional popular package names to protect, for example the most used
  /// internal packages of an organisation.
  final List<String> popular;
}
