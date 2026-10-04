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

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/report/json_report_writer.dart';
import 'package:inspectra/src/report/markdown_report_writer.dart';
import 'package:inspectra/src/report/sarif_report_writer.dart';
import 'package:inspectra/src/report/snippet_sanitizer.dart';
import 'package:test/test.dart';

import '../support/sample_report.dart';

/// Tests the JSON, SARIF and Markdown writers and the sanitiser.
void main() {
  const report = SampleReport(<Finding>[
    Finding(
      ruleId: 'GHSA-1',
      source: FindingSource.osv,
      severity: Severity.critical,
      title: 'Bad | thing',
      packageName: 'http',
      packageVersion: '0.13.0',
      url: 'https://osv.dev/vulnerability/GHSA-1',
      location: SourceLocation('pubspec.lock'),
    ),
    Finding(
      ruleId: 'PROCESS_RUN',
      source: FindingSource.regex,
      severity: Severity.medium,
      title: 'OS process execution',
      location: SourceLocation('lib/a.dart', line: 4),
    ),
  ]);

  test('JSON documents carry schema and tool metadata', () {
    final json =
        jsonDecode(const JsonReportWriter().render(report, DateTime.utc(2026)))
            as Map<String, Object?>;
    expect(json['schemaVersion'], 1);
    expect((json['tool'] as Map)['version'], inspectraVersion);
    expect(json['command'], 'sample');
    expect(json['custom'], isTrue);
    expect(json['findings'], hasLength(2));
  });

  test('SARIF logs are valid 2.1.0 with fingerprints and levels', () {
    final sarif = jsonDecode(const SarifReportWriter().render(report)) as Map;
    expect(sarif['version'], '2.1.0');
    final run = (sarif['runs'] as List).single as Map;
    final rules = ((run['tool'] as Map)['driver'] as Map)['rules'] as List;
    expect(rules, hasLength(2));
    final results = run['results'] as List;
    final first = results.first as Map;
    expect(first['level'], 'error');
    expect(
      (first['partialFingerprints'] as Map)['inspectra/v1'],
      hasLength(64),
    );
    final second = results.last as Map;
    expect(second['level'], 'warning');
    final location = (second['locations'] as List).single as Map;
    expect(
      ((location['physicalLocation'] as Map)['region'] as Map)['startLine'],
      4,
    );
  });

  test('Markdown tables escape pipes', () {
    final markdown = const MarkdownReportWriter().render(report);
    expect(markdown, contains(r'Bad \| thing'));
    expect(markdown, contains('1 critical \u00B7 1 medium'));
    expect(
      const MarkdownReportWriter().render(const SampleReport(<Finding>[])),
      contains('No findings'),
    );
  });

  test('sanitiser makes invisible characters visible', () {
    expect(
      SnippetSanitizer.sanitize('a\u202Eb\x1B[31m'),
      r'a\u{202E}b\u{001B}[31m',
    );
    expect(SnippetSanitizer.sanitize('x' * 500).length, lessThan(200));
  });
}
