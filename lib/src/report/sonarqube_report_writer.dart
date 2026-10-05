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

import 'dart:convert';

import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/model/source_location.dart';
import 'package:inspectra/src/report/sarif_report_writer.dart';

/// Writes findings in the generic issue import format of SonarQube 10.3 and
/// later and SonarCloud, for `sonar.externalIssuesReportPaths`.
///
/// SonarQube attaches every issue to a file of the project, so findings
/// without a file, such as a misspelled environment variable, are left out.
final class SonarqubeReportWriter {
  /// Creates the writer.
  const SonarqubeReportWriter();

  /// Renders [findings].
  ///
  /// Returns the JSON document with `rules` and `issues` and a final line
  /// break.
  String render(List<Finding> findings) {
    final List<Finding> located = findings
        .where((finding) => finding.location != null)
        .toList();
    final rules = <String, Map<String, Object?>>{};
    for (final finding in located) {
      rules.putIfAbsent(finding.ruleId, () => _rule(finding));
    }
    final document = <String, Object?>{
      'rules': rules.values.toList(),
      'issues': <Map<String, Object?>>[
        for (final finding in located) _issue(finding),
      ],
    };
    return '${const JsonEncoder.withIndent('  ').convert(document)}\n';
  }

  /// Describes the rule of [finding].
  ///
  /// Returns the rule object.
  static Map<String, Object?> _rule(Finding finding) {
    final bool maintainability = SarifReportWriter.isMaintainability(finding);
    return <String, Object?>{
      'id': finding.ruleId,
      'name': finding.ruleId,
      'description': finding.title,
      'engineId': 'inspectra',
      'cleanCodeAttribute': maintainability ? 'CONVENTIONAL' : 'TRUSTWORTHY',
      'impacts': <Map<String, Object?>>[
        <String, Object?>{
          'softwareQuality': maintainability ? 'MAINTAINABILITY' : 'SECURITY',
          'severity': switch (finding.severity) {
            Severity.critical || Severity.high => 'HIGH',
            Severity.medium => 'MEDIUM',
            Severity.low || Severity.unknown => 'LOW',
          },
        },
      ],
    };
  }

  /// Describes [finding] as one issue.
  ///
  /// Returns the issue object.
  static Map<String, Object?> _issue(Finding finding) {
    final SourceLocation? location = finding.location;
    final int? line = location?.line;
    final String message = finding.description.isEmpty
        ? finding.title
        : '${finding.title}. ${finding.description}';
    return <String, Object?>{
      'ruleId': finding.ruleId,
      'primaryLocation': <String, Object?>{
        'message': message,
        'filePath': location?.path,
        if (line != null) 'textRange': <String, Object?>{'startLine': line},
      },
    };
  }
}
