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

import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/model/source_location.dart';

/// Collects the findings of `config lint`, located at the options they are
/// about.
final class ConfigLintCollector {
  /// Creates a collector that locates options through [recorder].
  ConfigLintCollector(this.recorder);

  /// Where each option is configured.
  final ConfigRecorder recorder;

  /// The findings so far.
  final findings = <Finding>[];

  /// Returns the effective value of the option [key].
  Object? valueOf(String key) => recorder[key]?.value;

  /// Adds the finding [ruleId] of [severity] about the option [key], or
  /// about the environment [variable].
  void add(
    String? key,
    String ruleId,
    Severity severity,
    String title,
    String description, {
    String? variable,
    String? package,
  }) {
    final ConfigEntry? entry = key == null ? null : recorder[key];
    final String? setBy = entry?.origin == ConfigOrigin.environment
        ? entry?.variable
        : variable;
    findings.add(
      Finding(
        ruleId: ruleId,
        source: FindingSource.config,
        severity: severity,
        title: title,
        description: description,
        location: _locate(entry),
        packageName: package,
        attributes: <String, Object?>{
          'option': ?key,
          'variable': ?setBy,
          'origin': ?entry?.origin.id,
        },
      ),
    );
  }

  /// Returns where [entry] is written in the configuration file, or `null`
  /// when it is not there.
  SourceLocation? _locate(ConfigEntry? entry) {
    final String? source = entry?.file ?? recorder.source;
    if (entry == null || source == null) {
      return null;
    }
    if (entry.origin != ConfigOrigin.file) {
      return null;
    }
    return SourceLocation(source, line: entry.line);
  }
}
