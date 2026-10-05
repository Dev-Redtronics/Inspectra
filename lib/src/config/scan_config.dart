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

/// Settings shared by every Trivy scan.
abstract base class ScanConfig {
  /// Creates the shared settings.
  const ScanConfig({
    required this.enabled,
    required this.failOnFindings,
    required this.severity,
  });

  /// Reads the `severity` list of a scan section in [yaml].
  ///
  /// Returns the severities, or [fallback] when the list is absent.
  ///
  /// Throws an `InspectraConfigException` for unknown severities.
  static List<Severity> readSeverities(
    YamlReader yaml,
    List<Severity> fallback,
  ) => yaml.enums(
    'severity',
    fallback: fallback,
    parse: Severity.tryParse,
    options: Severity.values.map((severity) => severity.label).toList(),
    name: (severity) => severity.label,
  );

  /// Whether this scan runs when Trivy is enabled.
  final bool enabled;

  /// Whether findings fail the build or the command.
  final bool failOnFindings;

  /// The severities that are reported; anything else is ignored.
  final List<Severity> severity;
}
