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

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/report/checkstyle_report_writer.dart';
import 'package:inspectra/src/report/gitlab_report_writer.dart';
import 'package:inspectra/src/report/junit_report_writer.dart';
import 'package:inspectra/src/report/output_format.dart';
import 'package:inspectra/src/report/report_renderer.dart';
import 'package:inspectra/src/report/report_section.dart';
import 'package:inspectra/src/report/section_status.dart';
import 'package:inspectra/src/report/sonarqube_report_writer.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import '../support/sample_report.dart';

/// Tests the JUnit, GitLab Code Quality, SonarQube and Checkstyle writers.
void main() {
  const vulnerable = Finding(
    ruleId: 'GHSA-1',
    source: FindingSource.osv,
    severity: Severity.critical,
    title: 'Bad <thing> & "worse"',
    description: 'Upgrade the package.',
    packageName: 'http',
    packageVersion: '0.13.0',
    location: SourceLocation('pubspec.lock'),
  );
  const styled = Finding(
    ruleId: 'no_print',
    source: FindingSource.style,
    severity: Severity.low,
    title: 'Do not print',
    location: SourceLocation('lib/a.dart', line: 4),
  );
  const unlocated = Finding(
    ruleId: 'CONFIG_UNKNOWN_VARIABLE',
    source: FindingSource.config,
    severity: Severity.medium,
    title: 'INSPECTRA_TRIVY_MOD is unknown',
  );
  final generatedAt = DateTime.utc(2026, 10, 5);

  group('JUnit', () {
    XmlDocument render(List<ReportSection> sections) => XmlDocument.parse(
      const JunitReportWriter().render(sections, generatedAt),
    );

    test('writes one suite per section and one case per finding', () {
      final XmlDocument document = render(<ReportSection>[
        const ReportSection(
          id: 'scan',
          title: 'Supply chain',
          status: SectionStatus.failed,
          summary: '2 finding(s)',
          findings: <Finding>[vulnerable, styled],
        ),
        const ReportSection(
          id: 'format',
          title: 'Format',
          status: SectionStatus.passed,
          summary: 'All files are formatted',
        ),
        const ReportSection(
          id: 'coverage',
          title: 'Coverage',
          status: SectionStatus.skipped,
          summary: 'Skipped',
          reason: 'Not enabled',
        ),
        const ReportSection(
          id: 'trivy-secret',
          title: 'Trivy secret',
          status: SectionStatus.error,
          summary: 'Could not run completely',
          reason: 'Trivy is missing',
        ),
      ]);
      final XmlElement root = document.rootElement;
      expect(root.name.local, 'testsuites');
      expect(root.getAttribute('tests'), '5');
      expect(root.getAttribute('failures'), '2');
      expect(root.getAttribute('errors'), '1');
      final List<XmlElement> suites = root.findElements('testsuite').toList();
      expect(suites.map((suite) => suite.getAttribute('name')), <String>[
        'Supply chain',
        'Format',
        'Coverage',
        'Trivy secret',
      ]);
      final XmlElement failure = suites.first.findAllElements('failure').first;
      expect(failure.getAttribute('message'), 'Bad <thing> & "worse"');
      expect(failure.getAttribute('type'), 'CRITICAL');
      expect(suites[1].findAllElements('testcase'), hasLength(1));
      expect(suites[1].findAllElements('failure'), isEmpty);
      expect(
        suites[2].findAllElements('skipped').single.getAttribute('message'),
        'Not enabled',
      );
      expect(
        suites[3].findAllElements('error').single.getAttribute('message'),
        'Trivy is missing',
      );
    });

    test('findings of a passed section are not failures', () {
      final XmlDocument document = render(<ReportSection>[
        const ReportSection(
          id: 'lint',
          title: 'Lint',
          status: SectionStatus.passed,
          summary: '1 diagnostic',
          findings: <Finding>[styled],
        ),
      ]);
      expect(document.findAllElements('failure'), isEmpty);
      expect(document.findAllElements('testcase'), hasLength(1));
    });
  });

  group('GitLab Code Quality', () {
    List<Map<String, Object?>> render(List<Finding> findings) =>
        <Map<String, Object?>>[
          for (final Object? issue in jsonDecode(
            const GitlabReportWriter().render(findings),
          ) as List<Object?>)
            issue! as Map<String, Object?>,
        ];

    test('maps severities, categories and locations', () {
      final List<Map<String, Object?>> issues = render(<Finding>[
        vulnerable,
        styled,
        unlocated,
      ]);
      expect(issues.map((issue) => issue['severity']), <String>[
        'critical',
        'info',
        'minor',
      ]);
      expect(issues.first['categories'], <String>['Security']);
      expect(issues[1]['categories'], <String>['Style']);
      expect(issues.first['check_name'], 'GHSA-1');
      expect(
        (issues.first['content']! as Map<String, Object?>)['body'],
        'Upgrade the package.',
      );
      expect(issues[1]['location'], <String, Object?>{
        'path': 'lib/a.dart',
        'lines': <String, Object?>{'begin': 4},
      });
      expect(issues[2]['location'], <String, Object?>{
        'path': '.',
        'lines': <String, Object?>{'begin': 1},
      });
    });

    test('fingerprints survive moved lines and tell repeats apart', () {
      const moved = Finding(
        ruleId: 'no_print',
        source: FindingSource.style,
        severity: Severity.low,
        title: 'Do not print',
        location: SourceLocation('lib/a.dart', line: 40),
      );
      final Object? before = render(<Finding>[styled]).single['fingerprint'];
      final List<Map<String, Object?>> after = render(<Finding>[moved, styled]);
      expect(after.first['fingerprint'], before);
      expect(after.last['fingerprint'], isNot(before));
      expect(before, hasLength(64));
    });
  });

  group('SonarQube', () {
    test(
      'writes rules with impacts and leaves out findings without a file',
      () {
        final document = jsonDecode(
          const SonarqubeReportWriter().render(<Finding>[
            vulnerable,
            styled,
            styled,
            unlocated,
          ]),
        ) as Map<String, Object?>;
        final rules = document['rules']! as List<Object?>;
        final issues = document['issues']! as List<Object?>;
        expect(rules, hasLength(2));
        expect(issues, hasLength(3));
        final first = rules.first! as Map<String, Object?>;
        expect(first['engineId'], 'inspectra');
        expect(first['cleanCodeAttribute'], 'TRUSTWORTHY');
        expect(first['impacts'], <Object?>[
          <String, Object?>{'softwareQuality': 'SECURITY', 'severity': 'HIGH'},
        ]);
        final second = rules.last! as Map<String, Object?>;
        expect(second['cleanCodeAttribute'], 'CONVENTIONAL');
        final issue = issues[1]! as Map<String, Object?>;
        expect(issue['primaryLocation'], <String, Object?>{
          'message': 'Do not print',
          'filePath': 'lib/a.dart',
          'textRange': <String, Object?>{'startLine': 4},
        });
        expect(
          (issues.first! as Map<String, Object?>)['primaryLocation'],
          isNot(contains('textRange')),
        );
      },
    );
  });

  group('Checkstyle', () {
    test('groups findings by file and escapes messages', () {
      final document = XmlDocument.parse(
        const CheckstyleReportWriter().render(<Finding>[
          vulnerable,
          styled,
          unlocated,
        ]),
      );
      final List<XmlElement> files = document.rootElement
          .findElements('file')
          .toList();
      expect(files.map((file) => file.getAttribute('name')), <String>[
        'pubspec.lock',
        'lib/a.dart',
        '.',
      ]);
      final XmlElement error = files.first.findElements('error').single;
      expect(error.getAttribute('severity'), 'error');
      expect(
        error.getAttribute('message'),
        'Bad <thing> & "worse". Upgrade the package.',
      );
      expect(error.getAttribute('source'), 'inspectra.osv.GHSA-1');
      expect(files[1].findElements('error').single.getAttribute('line'), '4');
      expect(
        files[2].findElements('error').single.getAttribute('severity'),
        'warning',
      );
    });
  });

  test('every format renders any command report', () {
    const report = SampleReport(<Finding>[vulnerable, styled]);
    for (final OutputFormat format in OutputFormat.values.where(
      (format) => format != OutputFormat.text,
    )) {
      final String rendered = const ReportRenderer().render(
        report,
        format,
        style: const AnsiStyler(enabled: false),
        generatedAt: generatedAt,
      );
      expect(rendered, isNotEmpty, reason: format.id);
    }
    final String junit = const ReportRenderer().render(
      report,
      OutputFormat.junit,
      style: const AnsiStyler(enabled: false),
      generatedAt: generatedAt,
      failOn: Severity.high,
    );
    expect(XmlDocument.parse(junit).findAllElements('failure'), hasLength(2));
  });
}
