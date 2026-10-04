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

/// Public API validation, the `api:` section.
final class ApiConfig {
  /// Creates the API validation settings.
  const ApiConfig({
    required this.enabled,
    required this.output,
    required this.ignoredLibraries,
    required this.nonPublicAnnotations,
  });

  /// Reads the settings from the `api:` section in [yaml] for the package
  /// [packageName].
  ///
  /// Returns the settings.
  ///
  /// Throws an `InspectraConfigException` for unknown keys or invalid
  /// values.
  factory ApiConfig.fromYaml(YamlReader yaml, String packageName) {
    final config = ApiConfig(
      enabled: yaml.boolean('enabled', fallback: false),
      output: yaml.string('output', fallback: 'api/$packageName.api'),
      ignoredLibraries: yaml.strings('ignored_libraries', fallback: const []),
      nonPublicAnnotations: yaml.strings(
        'non_public_annotations',
        fallback: const ['internal', 'visibleForTesting'],
      ),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// Whether the API dump is written and checked. Off by default.
  final bool enabled;

  /// The dump file, relative to the package root.
  final String output;

  /// Globs of public libraries left out of the dump, relative to the
  /// package root, for example `lib/testing.dart`.
  final List<String> ignoredLibraries;

  /// Names of annotations that keep a declaration out of the dump.
  ///
  /// Either the name of a constant (`internal`, `visibleForTesting`) or of
  /// the annotation class (`Internal`).
  final List<String> nonPublicAnnotations;
}
