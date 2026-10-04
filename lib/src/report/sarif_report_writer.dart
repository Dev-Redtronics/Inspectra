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

import 'dart:convert';

import '../model/finding.dart';
import '../model/severity.dart';
import '../version.dart';
import 'command_report.dart';

/// Renders reports as SARIF 2.1.0 logs.
///
/// SARIF is understood by GitHub code scanning, Azure DevOps, GitLab and most
/// security dashboards. Every finding becomes a result with a stable
/// `partialFingerprints` entry, so alerts are tracked across runs, and every
/// rule carries a numeric `security-severity` so GitHub ranks it correctly.
final class SarifReportWriter {
  /// Creates a writer.
  const SarifReportWriter();

  /// The numeric security severity GitHub uses to rank alerts.
  static const Map<Severity, String> _securitySeverity = <Severity, String>{
    Severity.critical: '9.5',
    Severity.high: '8.0',
    Severity.medium: '5.5',
    Severity.low: '2.0',
    Severity.unknown: '1.0',
  };

  /// Renders [report].
  ///
  /// Returns the SARIF document followed by a line break.
  String render(CommandReport report) {
    final rules = <String, Map<String, Object?>>{};
    for (final finding in report.findings) {
      rules.putIfAbsent(finding.ruleId, () => _rule(finding));
    }
    final document = <String, Object?>{
      r'$schema': 'https://json.schemastore.org/sarif-2.1.0.json',
      'version': '2.1.0',
      'runs': <Object?>[
        <String, Object?>{
          'tool': <String, Object?>{
            'driver': <String, Object?>{
              'name': 'Inspectra',
              'version': inspectraVersion,
              'semanticVersion': inspectraVersion,
              'informationUri': 'https://github.com/dev-redtronics/inspectra',
              'rules': rules.values.toList(),
            },
          },
          'automationDetails': <String, Object?>{
            'id': 'inspectra/${report.command}/',
          },
          'results': report.findings.map(_result).toList(),
        },
      ],
    };
    return '${const JsonEncoder.withIndent('  ').convert(document)}\n';
  }

  /// Describes the rule of [finding].
  ///
  /// Returns the SARIF reporting descriptor.
  Map<String, Object?> _rule(Finding finding) {
    final url = finding.url;
    return <String, Object?>{
      'id': finding.ruleId,
      'name': finding.ruleId,
      'shortDescription': <String, Object?>{'text': finding.title},
      'helpUri': ?url,
      'properties': <String, Object?>{
        'tags': <String>['security', finding.source.id],
        'security-severity': _securitySeverity[finding.severity],
      },
    };
  }

  /// Converts [finding] into a SARIF result.
  ///
  /// Returns the result object.
  Map<String, Object?> _result(Finding finding) {
    final location = finding.location;
    final message = finding.description.isEmpty
        ? finding.title
        : '${finding.title}\n\n${finding.description}';
    return <String, Object?>{
      'ruleId': finding.ruleId,
      'level': _level(finding.severity),
      'message': <String, Object?>{'text': message},
      if (location != null)
        'locations': <Object?>[
          <String, Object?>{
            'physicalLocation': <String, Object?>{
              'artifactLocation': <String, Object?>{'uri': location.path},
              if (location.line != null)
                'region': <String, Object?>{'startLine': location.line},
            },
          },
        ],
      'partialFingerprints': <String, Object?>{
        'inspectra/v1': finding.fingerprint,
      },
      'properties': <String, Object?>{
        'severity': finding.severity.label,
        'source': finding.source.id,
        'package': ?finding.packageName,
        'version': ?finding.packageVersion,
        'fixedVersion': ?finding.fixedVersion,
      },
    };
  }

  /// Maps a severity to a SARIF result level.
  ///
  /// Returns `error`, `warning` or `note`.
  String _level(Severity severity) {
    return switch (severity) {
      Severity.critical => 'error',
      Severity.high => 'error',
      Severity.medium => 'warning',
      Severity.low => 'note',
      Severity.unknown => 'note',
    };
  }
}
