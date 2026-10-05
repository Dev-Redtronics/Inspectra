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
import 'package:inspectra/src/baseline/baseline.dart';
import 'package:inspectra/src/baseline/baseline_entry.dart';
import 'package:inspectra/src/baseline/baseline_gates.dart';
import 'package:inspectra/src/baseline/baseline_matcher.dart';
import 'package:inspectra/src/baseline/baseline_scope.dart';
import 'package:test/test.dart';

/// Tests applying the baseline to the results of the package checks.
void main() {
  /// Creates a matcher of [entries] with the settings [config].
  BaselineMatcher matcher(
    List<BaselineEntry> entries, {
    BaselineConfig config = const BaselineConfig(),
  }) => BaselineMatcher(baseline: Baseline(entries), config: config);

  /// Creates an entry of [scope] from [source] for [rule] in [path].
  BaselineEntry entry(
    BaselineScope scope,
    String source,
    String rule, {
    String? path,
    String? package,
    int count = 1,
  }) => BaselineEntry(
    scope: scope,
    source: source,
    rule: rule,
    count: count,
    severity: Severity.low,
    title: 'recorded',
    path: path,
    package: package,
  );

  /// Creates a style result of [violations] in `no_else`.
  StyleResult style(List<(String, int)> violations) => StyleResult(
    checked: 2,
    rules: const <String>['no_else'],
    violations: <StyleViolation>[
      for (final (path, line) in violations)
        StyleViolation(
          ruleId: 'no_else',
          path: path,
          line: line,
          column: 1,
          message: 'No else.',
        ),
    ],
    failOnFindings: true,
  );

  group('style', () {
    test('an empty baseline leaves the result untouched', () {
      final StyleResult result = style(<(String, int)>[('lib/a.dart', 1)]);
      expect(
        baselineStyle(result, matcher(const <BaselineEntry>[])),
        same(result),
      );
      expect(result.toJson().containsKey('baseline'), isFalse);
    });

    test('removes covered violations and reports what was covered', () {
      final StyleResult result = baselineStyle(
        style(<(String, int)>[('lib/a.dart', 1)]),
        matcher(<BaselineEntry>[
          entry(BaselineScope.style, 'style', 'no_else', path: 'lib/a.dart'),
          entry(BaselineScope.lint, 'analyzer', 'x', path: 'lib/a.dart'),
        ]),
      );
      expect(result.violations, isEmpty);
      expect(result.failed, isFalse);
      expect(result.render(), contains('1 finding(s) covered by the baseline'));
      expect(result.toJson()['baseline'], <String, Object?>{
        'covered': 1,
        'stale': 0,
      });
    });

    test('a new violation still fails next to covered ones', () {
      final StyleResult result = baselineStyle(
        style(<(String, int)>[('lib/a.dart', 1), ('lib/b.dart', 4)]),
        matcher(<BaselineEntry>[
          entry(BaselineScope.style, 'style', 'no_else', path: 'lib/a.dart'),
        ]),
      );
      expect(result.violations.single.path, 'lib/b.dart');
      expect(result.failed, isTrue);
    });

    test('stale entries fail only with fail_on_stale', () {
      final entries = <BaselineEntry>[
        entry(BaselineScope.style, 'style', 'no_else', path: 'lib/gone.dart'),
      ];
      final StyleResult lenient = baselineStyle(
        style(const <(String, int)>[]),
        matcher(entries),
      );
      expect(lenient.failed, isFalse);
      expect(lenient.render(), contains('1 baseline entry is fixed'));
      final StyleResult strict = baselineStyle(
        style(const <(String, int)>[]),
        matcher(entries, config: const BaselineConfig(failOnStale: true)),
      );
      expect(strict.failed, isTrue);
      expect(strict.render(), contains('(failing)'));
    });
  });

  test('lint covers diagnostics, also of the failing level', () {
    final LintResult result = baselineLint(
      LintResult(
        issues: const <LintIssue>[
          LintIssue(
            severity: LintLevel.error,
            type: 'COMPILE_TIME_ERROR',
            code: 'undefined_identifier',
            path: 'lib/a.dart',
            line: 3,
            column: 1,
            message: 'Undefined name.',
          ),
        ],
        failOn: LintLevel.info,
      ),
      matcher(<BaselineEntry>[
        entry(
          BaselineScope.lint,
          'analyzer',
          'undefined_identifier',
          path: 'lib/a.dart',
          count: 2,
        ),
      ]),
    );
    expect(result.issues, isEmpty);
    expect(result.failed, isFalse);
    expect(result.render(), contains('1 baseline entry is fixed'));
    expect(result.toJson()['baseline'], <String, Object?>{
      'covered': 1,
      'stale': 1,
    });
  });

  test('Trivy scans match their own entries and skip skipped scans', () {
    final List<ScanResult> results = baselineScans(
      <ScanResult>[
        ScanResult(
          scan: 'license',
          findings: const <ScanFinding>[
            ScanFinding(
              severity: Severity.high,
              target: 'left_pad 1.2.3',
              id: 'GPL-3.0',
              title: 'license',
            ),
            ScanFinding(
              severity: Severity.high,
              target: 'right_pad 2.0.0',
              id: 'GPL-3.0',
              title: 'license',
            ),
          ],
          failOnFindings: true,
        ),
        ScanResult.skipped(scan: 'vulnerability', reason: 'no lockfile'),
      ],
      matcher(<BaselineEntry>[
        entry(BaselineScope.trivy, 'license', 'GPL-3.0', package: 'left_pad'),
        entry(BaselineScope.trivy, 'secret', 'GPL-3.0', package: 'right_pad'),
        entry(BaselineScope.trivy, 'vulnerability', 'CVE-1', package: 'x'),
      ]),
    );
    final ScanResult license = results.first;
    expect(license.findings.single.target, 'right_pad 2.0.0');
    expect(license.failed, isTrue);
    expect(license.toJson()['baseline'], <String, Object?>{
      'covered': 1,
      'stale': 0,
    });
    expect(results.last.baseline, isNull);
    expect(results.last.skipped, 'no lockfile');
  });
}
