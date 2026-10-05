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
import 'package:inspectra/src/report/report_section.dart';
import 'package:inspectra/src/report/section_status.dart';
import 'package:xml/xml.dart';

/// Writes a report as JUnit XML, for the test result views of Jenkins,
/// Azure DevOps, GitLab and CircleCI.
///
/// Every section becomes a `testsuite`. A finding is a failed `testcase`; a
/// passed section without findings is one passed test case, a skipped one
/// a `skipped` test case and one that could not run an `error`.
final class JunitReportWriter {
  /// Creates the writer.
  const JunitReportWriter();

  /// Renders [sections], generated at [generatedAt].
  ///
  /// Returns the XML document with a final line break.
  String render(List<ReportSection> sections, DateTime generatedAt) {
    final builder = XmlBuilder()
      ..processing('xml', 'version="1.0" encoding="UTF-8"');
    final int tests = sections.fold(0, (sum, s) => sum + _testCount(s));
    final int failures = sections.fold(
      0,
      (sum, section) =>
          sum +
          (section.status == SectionStatus.failed
              ? section.findings.length
              : 0),
    );
    final int errors = sections
        .where((section) => section.status == SectionStatus.error)
        .length;
    builder.element(
      'testsuites',
      attributes: <String, String>{
        'name': 'inspectra',
        'tests': '$tests',
        'failures': '$failures',
        'errors': '$errors',
        'time': '0',
        'timestamp': generatedAt.toUtc().toIso8601String(),
      },
      nest: () {
        for (final section in sections) {
          _suite(builder, section);
        }
      },
    );
    final String xml = builder.buildDocument().toXmlString(
      pretty: true,
      indent: '  ',
    );
    return '$xml\n';
  }

  /// Returns the number of test cases [section] becomes.
  static int _testCount(ReportSection section) =>
      section.findings.isEmpty ? 1 : section.findings.length;

  /// Writes the test suite of [section] into [builder].
  static void _suite(XmlBuilder builder, ReportSection section) {
    final failed = section.status == SectionStatus.failed;
    final error = section.status == SectionStatus.error;
    final skipped = section.status == SectionStatus.skipped;
    builder.element(
      'testsuite',
      attributes: <String, String>{
        'name': section.title,
        'id': section.id,
        'tests': '${_testCount(section)}',
        'failures': failed ? '${section.findings.length}' : '0',
        'errors': error ? '1' : '0',
        'skipped': skipped ? '1' : '0',
        'time': '0',
      },
      nest: () {
        if (section.findings.isEmpty || error || skipped) {
          _summaryCase(builder, section);
          return;
        }
        for (final Finding finding in section.findings) {
          _findingCase(builder, section, finding, failed: failed);
        }
      },
    );
  }

  /// Writes the single test case of a section without findings, or of one
  /// that was skipped or could not run.
  static void _summaryCase(XmlBuilder builder, ReportSection section) {
    builder.element(
      'testcase',
      attributes: <String, String>{
        'classname': 'inspectra.${section.id}',
        'name': section.summary,
        'time': '0',
      },
      nest: () {
        final String reason = section.reason ?? section.summary;
        if (section.status == SectionStatus.skipped) {
          builder.element(
            'skipped',
            attributes: <String, String>{'message': reason},
          );
        }
        if (section.status == SectionStatus.error) {
          builder.element(
            'error',
            attributes: <String, String>{'message': reason},
            nest: reason,
          );
        }
      },
    );
  }

  /// Writes the test case of [finding] of [section]; it fails when the
  /// section [failed].
  static void _findingCase(
    XmlBuilder builder,
    ReportSection section,
    Finding finding, {
    required bool failed,
  }) {
    final where = finding.location == null ? '' : ' (${finding.location})';
    builder.element(
      'testcase',
      attributes: <String, String>{
        'classname': 'inspectra.${section.id}',
        'name': '${finding.ruleId}$where',
        'file': ?finding.location?.path,
        'time': '0',
      },
      nest: () {
        if (!failed) {
          return;
        }
        builder.element(
          'failure',
          attributes: <String, String>{
            'message': finding.title,
            'type': finding.severity.label,
          },
          nest: <String>[
            '${finding.severity.label} ${finding.ruleId}$where',
            finding.title,
            if (finding.description.isNotEmpty) finding.description,
          ].join('\n'),
        );
      },
    );
  }
}
