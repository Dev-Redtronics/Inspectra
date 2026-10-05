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
import 'package:inspectra/src/report/aggregate_report.dart';
import 'package:inspectra/src/report/report_section.dart';
import 'package:inspectra/src/report/report_sections.dart';
import 'package:inspectra/src/report/section_details.dart';
import 'package:inspectra/src/report/section_status.dart';
import 'package:test/test.dart';

import '../support/sample_report.dart';

/// Tests the sections of a report, the aggregate report and reading
/// findings and sections back from JSON.
void main() {
  const finding = Finding(
    ruleId: 'GHSA-1',
    source: FindingSource.osv,
    severity: Severity.high,
    title: 'Bad thing',
    description: 'Upgrade.',
    packageName: 'http',
    packageVersion: '0.13.0',
    fixedVersion: '0.13.6',
    aliases: <String>['CVE-1'],
    url: 'https://osv.dev/vulnerability/GHSA-1',
    snippet: 'http: 0.13.0',
    location: SourceLocation('pubspec.lock', line: 7),
    attributes: <String, Object?>{'scan': 'license'},
  );

  ReportSection section(
    String id,
    SectionStatus status, {
    List<Finding> findings = const <Finding>[],
  }) => ReportSection(
    id: id,
    title: id.toUpperCase(),
    status: status,
    summary: 'Summary of $id',
    findings: findings,
    reason: status == SectionStatus.skipped ? 'Not enabled' : null,
  );

  group('AggregateReport', () {
    test('an error outranks a failure, which outranks a pass', () {
      expect(
        AggregateReport(
          sections: <ReportSection>[
            section('a', SectionStatus.failed),
            section('b', SectionStatus.error),
          ],
        ).status,
        SectionStatus.error,
      );
      expect(
        AggregateReport(
          sections: <ReportSection>[
            section('a', SectionStatus.passed),
            section('b', SectionStatus.failed),
          ],
        ).status,
        SectionStatus.failed,
      );
      expect(
        AggregateReport(
          sections: <ReportSection>[
            section('a', SectionStatus.passed),
            section('b', SectionStatus.skipped),
          ],
        ).status,
        SectionStatus.passed,
      );
      expect(
        AggregateReport(
          sections: <ReportSection>[section('a', SectionStatus.skipped)],
        ).status,
        SectionStatus.skipped,
      );
    });

    test('fails on failed sections and names incomplete ones', () {
      final report = AggregateReport(
        sections: <ReportSection>[
          section('a', SectionStatus.failed, findings: <Finding>[finding]),
          section('b', SectionStatus.error),
        ],
        project: 'app 1.0.0',
      );
      expect(report.isFailing(Severity.critical), isTrue);
      expect(report.findings, <Finding>[finding]);
      expect(
        report.incompleteReason,
        'The report is incomplete: B could not run completely.',
      );
      expect(
        AggregateReport(
          sections: <ReportSection>[section('a', SectionStatus.passed)],
        ).incompleteReason,
        isNull,
      );
      final out = StringBuffer();
      report.writeText(out, const AnsiStyler(enabled: false));
      expect(out.toString(), contains('[FAILED]  A  Summary of a'));
      expect(out.toString(), contains('[ERROR]   B  Summary of b'));
      expect(
        out.toString(),
        contains('Overall: [ERROR]   1 finding(s) in 2 section(s).'),
      );
      final Map<String, Object?> json = report.toJson();
      expect(json['project'], 'app 1.0.0');
      expect(json['status'], 'error');
      expect(json['sections'], hasLength(2));
    });

    test('writes the reason of skipped sections', () {
      final out = StringBuffer();
      AggregateReport(
        sections: <ReportSection>[section('a', SectionStatus.skipped)],
      ).writeText(out, const AnsiStyler(enabled: false));
      expect(out.toString(), contains('Summary of a - Not enabled'));
    });
  });

  group('JSON', () {
    test('findings survive a round trip', () {
      final read = Finding.fromJson(
        jsonDecode(jsonEncode(finding.toJson())),
        'findings[0]',
      );
      expect(read.toJson(), finding.toJson());
    });

    test('malformed findings name their location', () {
      expect(
        () => Finding.fromJson('text', 'a.json: findings[0]'),
        throwsA(
          isA<InvalidInputException>().having(
            (error) => error.message,
            'message',
            contains('a.json: findings[0]'),
          ),
        ),
      );
      expect(
        () => Finding.fromJson(<String, Object?>{
          'ruleId': 'X',
          'title': 'Y',
          'source': 'nowhere',
          'severity': 'high',
        }, 'findings[1]'),
        throwsA(isA<InvalidInputException>()),
      );
    });

    test('sections survive a round trip with their details', () {
      final sections = <ReportSection>[
        const ReportSection(
          id: 'coverage',
          title: 'Coverage',
          status: SectionStatus.failed,
          summary: 'Low',
          metrics: <String, String>{'Files': '2'},
          findings: <Finding>[finding],
          details: CoverageDetails(
            files: <(String, int, int)>[('lib/a.dart', 4, 2)],
            untested: <String>['lib/b.dart'],
            percent: 50,
            minimum: 80,
          ),
        ),
        const ReportSection(
          id: 'api',
          title: 'Public API',
          status: SectionStatus.failed,
          summary: 'Differs',
          details: DiffDetails('+a'),
        ),
        const ReportSection(
          id: 'lint',
          title: 'Lint',
          status: SectionStatus.skipped,
          summary: 'Skipped',
          reason: 'Not enabled',
        ),
      ];
      for (final original in sections) {
        final read = ReportSection.fromJson(
          jsonDecode(jsonEncode(original.toJson())),
          'sections[0]',
        );
        expect(read.toJson(), original.toJson());
      }
    });

    test('malformed sections are rejected', () {
      expect(
        () => ReportSection.fromJson(<String, Object?>{
          'id': 'a',
          'title': 'A',
          'summary': 'S',
          'status': 'unknown',
        }, 'sections[0]'),
        throwsA(isA<InvalidInputException>()),
      );
      expect(
        () => ReportSection.fromJson(<Object?>[], 'sections[0]'),
        throwsA(isA<InvalidInputException>()),
      );
      final lenient = ReportSection.fromJson(<String, Object?>{
        'id': 'a',
        'title': 'A',
        'summary': 'S',
        'status': 'passed',
        'details': <String, Object?>{'percent': 'high'},
      }, 'sections[0]');
      expect(lenient.details, isA<NoDetails>());
    });

    test('statuses and sources parse their ids', () {
      expect(SectionStatus.tryParse('error'), SectionStatus.error);
      expect(SectionStatus.tryParse('broken'), isNull);
      expect(FindingSource.tryParse('quality'), FindingSource.quality);
      expect(FindingSource.tryParse('nowhere'), isNull);
    });
  });

  test('any command report becomes one section', () {
    const report = SampleReport(<Finding>[finding]);
    final ReportSection failed = sectionOf(report, Severity.high);
    expect(failed.id, 'sample');
    expect(failed.status, SectionStatus.failed);
    expect(failed.summary, startsWith('1 finding(s): '));
    expect(sectionOf(report, Severity.critical).status, SectionStatus.passed);
    expect(sectionsOf(report, Severity.high), hasLength(1));
    final aggregate = AggregateReport(
      sections: <ReportSection>[section('a', SectionStatus.passed)],
    );
    expect(sectionsOf(aggregate, Severity.high), aggregate.sections);
    expect(sectionTitle('config lint'), 'Configuration');
    expect(sectionTitle('custom'), 'custom');
    expect(findingSummary(const <Finding>[]), 'No findings');
  });
}
