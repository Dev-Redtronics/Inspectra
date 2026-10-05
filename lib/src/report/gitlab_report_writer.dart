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

import 'package:crypto/crypto.dart';
import 'package:inspectra/src/baseline/baseline_candidates.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/sarif_report_writer.dart';

/// Writes findings as a GitLab Code Quality report, the CodeClimate JSON
/// that the merge request widget shows.
///
/// The fingerprint leaves out line numbers and package versions, like the
/// baseline, and counts repeated findings, so that moving code does not make
/// GitLab report a finding as new and fixed at once.
final class GitlabReportWriter {
  /// Creates the writer.
  const GitlabReportWriter();

  /// Renders [findings].
  ///
  /// Returns the JSON array with a final line break.
  String render(List<Finding> findings) {
    final occurrences = <String, int>{};
    final issues = <Map<String, Object?>>[];
    for (final finding in findings) {
      final String key = findingCandidate(finding).key;
      final int occurrence = occurrences.update(
        key,
        (count) => count + 1,
        ifAbsent: () => 0,
      );
      issues.add(_issue(finding, '$key|$occurrence'));
    }
    return '${const JsonEncoder.withIndent('  ').convert(issues)}\n';
  }

  /// Returns the stable fingerprint of [identity].
  static String fingerprintOf(String identity) =>
      sha256.convert(utf8.encode(identity)).toString();

  /// Describes [finding], identified by [identity], as one issue.
  ///
  /// Returns the CodeClimate issue.
  static Map<String, Object?> _issue(Finding finding, String identity) =>
      <String, Object?>{
        'type': 'issue',
        'check_name': finding.ruleId,
        'description': finding.title,
        if (finding.description.isNotEmpty)
          'content': <String, Object?>{'body': finding.description},
        'categories': <String>[
          if (SarifReportWriter.isMaintainability(finding)) 'Style',
          if (!SarifReportWriter.isMaintainability(finding)) 'Security',
        ],
        'severity': switch (finding.severity) {
          Severity.critical => 'critical',
          Severity.high => 'major',
          Severity.medium => 'minor',
          Severity.low => 'info',
          Severity.unknown => 'info',
        },
        'engine_name': 'inspectra',
        'fingerprint': fingerprintOf(identity),
        'location': <String, Object?>{
          'path': finding.location?.path ?? '.',
          'lines': <String, Object?>{'begin': finding.location?.line ?? 1},
        },
      };
}
