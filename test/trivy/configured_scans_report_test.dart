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

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/trivy/configured_scans_report.dart';
import 'package:inspectra/src/trivy/trivy_outcome.dart';
import 'package:inspectra/src/trivy/trivy_provision.dart';
import 'package:test/test.dart';

/// Tests the report of `inspectra trivy` over the configured scans.
void main() {
  /// A secret scan with one critical finding that fails when [failing].
  ScanResult secretScan({required bool failing}) => ScanResult(
    scan: 'secret',
    failOnFindings: failing,
    findings: const <ScanFinding>[
      ScanFinding(
        severity: Severity.critical,
        target: 'lib/a.dart',
        id: 'github-pat',
        title: 'GitHub Personal Access Token',
        detail: 'line 1',
      ),
    ],
  );

  /// The report over [results], with Trivy skipped for lack of a binary.
  ConfiguredScansReport report(List<ScanResult> results) =>
      ConfiguredScansReport(
        results: results,
        outcome: const TrivyOutcome(
          provision: TrivyUnavailable('Trivy is not installed.'),
          findings: <Finding>[],
        ),
      );

  test('normalises the findings of every scan', () {
    final ConfiguredScansReport subject = report(<ScanResult>[
      secretScan(failing: true),
      ScanResult.skipped(scan: 'license', reason: 'no pubspec.lock found.'),
    ]);

    expect(subject.command, 'trivy');
    final Finding finding = subject.findings.single;
    expect(finding.ruleId, 'github-pat');
    expect(finding.source, FindingSource.trivy);
    expect(finding.severity, Severity.critical);
    expect(finding.description, 'line 1');
    expect(finding.location?.path, 'lib/a.dart');
    expect(finding.attributes, <String, Object?>{'scan': 'secret'});
  });

  test('fails only when a scan fails under its own settings', () {
    expect(
      report(<ScanResult>[secretScan(failing: true)]).isFailing(Severity.low),
      isTrue,
    );
    expect(
      report(<ScanResult>[secretScan(failing: false)])
          .isFailing(Severity.unknown),
      isFalse,
    );
  });

  test('serialises the provisioning and every scan', () {
    final Map<String, Object?> json = report(<ScanResult>[
      secretScan(failing: true),
    ]).toJson();

    expect(json['trivy'], <String, Object?>{
      'status': 'skipped',
      'reason': 'Trivy is not installed.',
    });
    expect(json['scans'], hasLength(1));
  });

  test('renders every scan as text', () {
    final out = StringBuffer();
    report(<ScanResult>[
      secretScan(failing: true),
      ScanResult.skipped(scan: 'license', reason: 'no pubspec.lock found.'),
    ]).writeText(out, const AnsiStyler(enabled: false));

    expect(out.toString(), contains('Trivy secret scan: 1 finding(s).'));
    expect(out.toString(), contains('[CRITICAL] lib/a.dart: github-pat'));
    expect(
      out.toString(),
      contains('Trivy license scan skipped: no pubspec.lock found.'),
    );
  });
}
