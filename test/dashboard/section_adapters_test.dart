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

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/dashboard/section_adapters.dart';
import 'package:inspectra/src/report/report_section.dart';
import 'package:inspectra/src/report/section_details.dart';
import 'package:inspectra/src/report/section_status.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

/// Tests the conversion of the package check results into report
/// sections.
void main() {
  test('unformatted files become low findings', () {
    final ReportSection section = formatSection(
      FormatResult(
        checked: 3,
        unformatted: <String>['lib/b.dart', 'lib/a.dart'],
        failOnFindings: true,
      ),
    );
    expect(section.status, SectionStatus.failed);
    expect(section.summary, '2 of 3 file(s) are not formatted');
    expect(section.findings.map((f) => f.location?.path), <String>[
      'lib/a.dart',
      'lib/b.dart',
    ]);
    expect(section.findings.first.ruleId, 'UNFORMATTED');
    expect(section.findings.first.source, FindingSource.quality);
    expect(section.findings.first.attributes['check'], 'format');
    final ReportSection clean = formatSection(
      FormatResult(checked: 3, unformatted: <String>[], failOnFindings: true),
    );
    expect(clean.status, SectionStatus.passed);
    expect(clean.summary, 'All 3 file(s) are formatted');
  });

  test('lint diagnostics keep their code and map their level', () {
    LintIssue issue(LintLevel level, String code) => LintIssue(
      severity: level,
      type: 'LINT',
      code: code,
      path: 'lib/a.dart',
      line: 2,
      column: 1,
      message: 'Message of $code.',
    );
    final ReportSection section = lintSection(
      LintResult(
        issues: <LintIssue>[
          issue(LintLevel.error, 'undefined_name'),
          issue(LintLevel.warning, 'unused_import'),
          issue(LintLevel.info, 'prefer_const'),
        ],
        failOn: LintLevel.warning,
        baseline: const BaselineSummary(
          covered: 2,
          stale: 1,
          failOnStale: false,
        ),
      ),
    );
    expect(section.status, SectionStatus.failed);
    expect(section.findings.map((f) => f.severity), <Severity>[
      Severity.high,
      Severity.medium,
      Severity.low,
    ]);
    expect(section.findings.first.ruleId, 'undefined_name');
    expect(section.findings.first.location.toString(), 'lib/a.dart:2');
    expect(section.metrics['Errors'], '1');
    expect(section.metrics['Fails from'], 'warning');
    expect(section.metrics['Covered by baseline'], '2');
    expect(section.metrics['Stale baseline entries'], '1');
  });

  test('style violations become style findings', () {
    final ReportSection section = styleSection(
      StyleResult(
        checked: 2,
        rules: const <String>['no_else'],
        violations: const <StyleViolation>[
          StyleViolation(
            ruleId: 'no_else',
            path: 'lib/a.dart',
            line: 3,
            column: 1,
            message: 'No else.',
          ),
        ],
        failOnFindings: true,
      ),
    );
    expect(section.status, SectionStatus.failed);
    expect(section.summary, '1 violation(s) in 1 file(s)');
    expect(section.findings.single.source, FindingSource.style);
  });

  test('the API check reports a missing dump and a diff', () {
    final ReportSection missing = apiSection(
      const ApiCheckResult(dumpPath: 'api/a.api', diff: null, missing: true),
    );
    expect(missing.findings.single.ruleId, 'API_DUMP_MISSING');
    expect(missing.details, isA<NoDetails>());
    final ReportSection changed = apiSection(
      const ApiCheckResult(dumpPath: 'api/a.api', diff: '+x', missing: false),
    );
    expect(changed.status, SectionStatus.failed);
    expect(changed.findings.single.ruleId, 'API_CHANGED');
    expect((changed.details as DiffDetails).diff, '+x');
    final ReportSection same = apiSection(
      const ApiCheckResult(dumpPath: 'api/a.api', diff: null, missing: false),
    );
    expect(same.status, SectionStatus.passed);
    expect(same.findings, isEmpty);
    expect(same.summary, 'Matches api/a.api');
  });

  test('semantic versioning lists the API changes', () {
    final ReportSection violated = semverSection(
      evaluateSemver(
        before: 'library a\n\nint x();\nint y();\n',
        after: 'library a\n\nint x();\nint z();\n',
        baseline: 'v1.0.0',
        baselineVersion: Version(1, 0, 0),
        version: Version(1, 1, 0),
      ),
    );
    expect(violated.status, SectionStatus.failed);
    expect(violated.summary, 'Version 1.1.0 is too low; 2.0.0 is required');
    expect(violated.metrics['Breaking changes'], '1');
    expect(violated.findings.single.ruleId, 'SEMVER_VIOLATION');
    expect(
      (violated.details as DiffDetails).diff,
      '- y: The declaration was removed.\n+ z: The declaration was added.',
    );
    final ReportSection same = semverSection(
      evaluateSemver(
        before: 'library a\n\nint x();\n',
        after: 'library a\n\nint x();\n',
        baseline: 'v1.0.0',
        baselineVersion: Version(1, 0, 0),
        version: Version(1, 0, 0),
      ),
    );
    expect(same.status, SectionStatus.passed);
    expect(same.summary, '0 API change(s) since v1.0.0, version 1.0.0');
    expect(same.metrics['Required'], '-');
    expect(same.details, isA<NoDetails>());
    final ReportSection skipped = semverSection(
      const SemverResult.skipped('no release tag yet.'),
    );
    expect(skipped.status, SectionStatus.skipped);
  });

  test('changelog problems keep their line', () {
    final ReportSection section = changelogSection(
      const ChangelogCheckResult(
        path: 'CHANGELOG.md',
        version: '1.0.0',
        problems: <ChangelogProblem>[
          ChangelogProblem('Version 1.0.0 is missing.', line: 4),
        ],
      ),
    );
    expect(section.status, SectionStatus.failed);
    expect(section.findings.single.location.toString(), 'CHANGELOG.md:4');
    final ReportSection valid = changelogSection(
      const ChangelogCheckResult(
        path: 'CHANGELOG.md',
        version: '1.0.0',
        problems: <ChangelogProblem>[],
      ),
    );
    expect(valid.summary, 'CHANGELOG.md documents version 1.0.0');
  });

  test(
    'Trivy scans become one section each, skipped when they did not run',
    () {
      final ReportSection section = trivySection(
        ScanResult(
          scan: 'license',
          findings: const <ScanFinding>[
            ScanFinding(
              severity: Severity.high,
              target: 'left_pad 1.2.3',
              id: 'GPL-3.0',
              title: 'license',
            ),
          ],
          failOnFindings: true,
        ),
      );
      expect(section.id, 'trivy-license');
      expect(section.title, 'Trivy license');
      expect(section.status, SectionStatus.failed);
      expect(section.findings.single.source, FindingSource.trivy);
      final ReportSection skipped = trivySection(
        ScanResult.skipped(scan: 'vulnerability', reason: 'no lockfile'),
      );
      expect(skipped.status, SectionStatus.skipped);
      expect(skipped.reason, 'no lockfile');
    },
  );

  test('coverage carries every file and fails below the threshold', () {
    final ReportSection section = coverageSection(
      CoverageReport(
        files: <FileCoverage>[
          const FileCoverage('lib/a.dart', 10, 5),
          const FileCoverage('lib/b.dart', 10, 10),
        ],
        untested: const <String>['lib/c.dart'],
        lcovPath: 'coverage/lcov.info',
        minLineCoverage: 90,
      ),
    );
    expect(section.status, SectionStatus.failed);
    expect(section.summary, 'Line coverage 75.00% of the required 90.00%');
    expect(section.findings.single.ruleId, 'COVERAGE_BELOW_THRESHOLD');
    final details = section.details as CoverageDetails;
    expect(details.files, <(String, int, int)>[
      ('lib/a.dart', 10, 5),
      ('lib/b.dart', 10, 10),
    ]);
    expect(details.untested, <String>['lib/c.dart']);
    expect(details.minimum, 90);
    final ReportSection open = coverageSection(
      CoverageReport(
        files: <FileCoverage>[const FileCoverage('lib/a.dart', 4, 1)],
        untested: const <String>[],
        lcovPath: 'coverage/lcov.info',
        minLineCoverage: null,
      ),
    );
    expect(open.status, SectionStatus.passed);
    expect(open.summary, 'Line coverage 25.00%, no threshold');
    expect(open.metrics['Threshold'], '-');
  });

  test('sections that did not run explain why', () {
    final ReportSection off = notEnabledSection('lint', 'Lint', 'lint.enabled');
    expect(off.status, SectionStatus.skipped);
    expect(off.reason, 'Not enabled; set lint.enabled: true to run it.');
    final ReportSection broken = errorSection('scan', 'Supply chain', 'boom');
    expect(broken.status, SectionStatus.error);
    expect(broken.reason, 'boom');
  });
}
