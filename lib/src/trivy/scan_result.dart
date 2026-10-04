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

import 'package:inspectra/src/trivy/finding.dart';

/// The outcome of one scan.
class ScanResult {
  /// Creates the outcome of the scan named [scan].
  ScanResult({
    required this.scan,
    required List<ScanFinding> findings,
    required this.failOnFindings,
    this.skipped,
  }) : findings = List<ScanFinding>.unmodifiable(
         <ScanFinding>[...findings]..sort((a, b) {
           final int bySeverity = a.severity.index.compareTo(b.severity.index);
           if (bySeverity != 0) {
             return bySeverity;
           }
           final int byTarget = a.target.compareTo(b.target);
           if (byTarget != 0) {
             return byTarget;
           }
           return a.id.compareTo(b.id);
         }),
       );

  /// A scan that did not run, and why.
  ScanResult.skipped({required this.scan, required String reason})
    : findings = const [],
      failOnFindings = false,
      skipped = reason;

  /// The name of the scan, such as `secret`.
  final String scan;

  /// What the scan reported, most severe first.
  final List<ScanFinding> findings;

  /// Whether [findings] make the scan fail.
  final bool failOnFindings;

  /// Why the scan did not run, or `null` when it did.
  final String? skipped;

  /// Whether the scan failed.
  bool get failed => failOnFindings && findings.isNotEmpty;

  /// A readable summary for the console or the build log.
  String render() {
    if (skipped != null) {
      return 'Trivy $scan scan skipped: $skipped';
    }
    if (findings.isEmpty) {
      return 'Trivy $scan scan: no findings.';
    }

    final suffix = failed ? '' : ' (not failing)';
    final buffer = StringBuffer()
      ..writeln('Trivy $scan scan: ${findings.length} finding(s)$suffix.');
    for (final ScanFinding finding in findings) {
      buffer.write(
        '  [${finding.severity.trivyName}] ${finding.target}: '
        '${finding.id} - ${finding.title}',
      );
      if (finding.detail != null) {
        buffer.write(' (${finding.detail})');
      }
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }

  /// Serializes this result for the JSON report.
  Map<String, Object?> toJson() => {
    'scan': scan,
    'failed': failed,
    if (skipped != null) 'skipped': skipped,
    'findings': [for (final finding in findings) finding.toJson()],
  };
}
