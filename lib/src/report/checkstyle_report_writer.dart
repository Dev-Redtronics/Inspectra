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

import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:xml/xml.dart';

/// Writes findings as Checkstyle XML, for Jenkins Warnings NG, Bitbucket
/// and the many tools that read it.
///
/// Findings are grouped by file; those without a file are listed under `.`.
final class CheckstyleReportWriter {
  /// Creates the writer.
  const CheckstyleReportWriter();

  /// Renders [findings].
  ///
  /// Returns the XML document with a final line break.
  String render(List<Finding> findings) {
    final builder = XmlBuilder()
      ..processing('xml', 'version="1.0" encoding="UTF-8"');
    final byFile = <String, List<Finding>>{};
    for (final finding in findings) {
      byFile
          .putIfAbsent(finding.location?.path ?? '.', () => <Finding>[])
          .add(finding);
    }
    builder.element(
      'checkstyle',
      attributes: <String, String>{'version': '4.3'},
      nest: () {
        for (final MapEntry(key: path, value: entries) in byFile.entries) {
          builder.element(
            'file',
            attributes: <String, String>{'name': path},
            nest: () {
              for (final finding in entries) {
                _error(builder, finding);
              }
            },
          );
        }
      },
    );
    final String xml = builder.buildDocument().toXmlString(
      pretty: true,
      indent: '  ',
    );
    return '$xml\n';
  }

  /// Writes [finding] as one `error` element into [builder].
  static void _error(XmlBuilder builder, Finding finding) {
    builder.element(
      'error',
      attributes: <String, String>{
        'line': '${finding.location?.line ?? 1}',
        'severity': switch (finding.severity) {
          Severity.critical || Severity.high => 'error',
          Severity.medium => 'warning',
          Severity.low || Severity.unknown => 'info',
        },
        'message': finding.description.isEmpty
            ? finding.title
            : '${finding.title}. ${finding.description}',
        'source': 'inspectra.${finding.source.id}.${finding.ruleId}',
      },
    );
  }
}
