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

import 'package:inspectra/src/config/yaml_reader.dart';
import 'package:inspectra/src/model/severity.dart';

/// Settings of the baseline, the `baseline:` section of `inspectra.yaml`.
///
/// The baseline file records the findings a package has accepted for now;
/// `inspectra baseline create` writes it and the checks then report only
/// findings that are not recorded.
final class BaselineConfig {
  /// Creates baseline settings.
  const BaselineConfig({
    this.enabled = true,
    this.file = defaultFile,
    this.maxSeverity,
    this.failOnStale = false,
  });

  /// Reads the settings from the `baseline:` section in [yaml].
  ///
  /// Returns the settings.
  ///
  /// Throws an `InspectraConfigException` for unknown keys or invalid
  /// values.
  factory BaselineConfig.fromYaml(YamlReader yaml) {
    final severities = <String, Severity?>{
      for (final severity in Severity.values) severity.name: severity,
    };
    final config = BaselineConfig(
      enabled: yaml.boolean('enabled', fallback: true),
      file: yaml.string('file', fallback: defaultFile),
      maxSeverity: yaml.choice('max_severity', severities, fallback: null),
      failOnStale: yaml.boolean('fail_on_stale', fallback: false),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// The default location of the baseline file, relative to the package.
  static const defaultFile = 'inspectra-baseline.json';

  /// Whether the checks apply the baseline file when it exists.
  final bool enabled;

  /// The baseline file, relative to the package root.
  final String file;

  /// Findings more severe than this are never covered by the baseline, or
  /// `null` to let it cover every severity.
  final Severity? maxSeverity;

  /// Whether a check fails while recorded findings have been fixed and the
  /// baseline still lists them, so that `inspectra baseline prune` must run.
  final bool failOnStale;
}
