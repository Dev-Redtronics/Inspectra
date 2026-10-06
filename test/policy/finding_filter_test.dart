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
import 'package:inspectra/src/baseline/baseline_matcher.dart';
import 'package:inspectra/src/baseline/baseline_scope.dart';
import 'package:inspectra/src/policy/filter_outcome.dart';
import 'package:inspectra/src/policy/finding_filter.dart';
import 'package:test/test.dart';

/// Tests the reporting policy filter.
void main() {
  /// Creates a finding with [id] and [severity].
  Finding finding(String id, Severity severity) => Finding(
    ruleId: id,
    source: FindingSource.osv,
    severity: severity,
    title: id,
  );

  test('drops findings below the minimum severity', () {
    final filter = FindingFilter(
      minSeverity: Severity.high,
      rules: const <IgnoreRule>[],
      cliIgnores: const <String>[],
      now: DateTime.utc(2026),
    );
    final FilterOutcome outcome = filter.apply(<Finding>[
      finding('a', Severity.critical),
      finding('b', Severity.medium),
    ]);
    expect(outcome.kept.map((f) => f.ruleId), <String>['a']);
  });

  test('suppresses by flag and active rules but not expired rules', () {
    final filter = FindingFilter(
      minSeverity: Severity.unknown,
      rules: <IgnoreRule>[
        IgnoreRule(id: 'b', reason: 'r', expires: DateTime(2027)),
        IgnoreRule(id: 'c', reason: 'r', expires: DateTime(2020)),
      ],
      cliIgnores: const <String>['a'],
      now: DateTime.utc(2026),
    );
    final FilterOutcome outcome = filter.apply(<Finding>[
      finding('a', Severity.low),
      finding('b', Severity.low),
      finding('c', Severity.low),
    ]);
    expect(outcome.kept.map((f) => f.ruleId), <String>['c']);
    expect(outcome.suppressed, hasLength(2));
    expect(outcome.expiredRules.single.id, 'c');
  });

  test('leaves out what the baseline covers after the ignore rules', () {
    final filter = FindingFilter(
      minSeverity: Severity.unknown,
      rules: const <IgnoreRule>[],
      cliIgnores: const <String>['b'],
      now: DateTime.utc(2026),
      baseline: BaselineMatcher(
        baseline: Baseline(const <BaselineEntry>[
          BaselineEntry(
            scope: BaselineScope.scan,
            source: 'osv',
            rule: 'a',
            count: 1,
            severity: Severity.low,
            title: 'a',
          ),
          BaselineEntry(
            scope: BaselineScope.scan,
            source: 'osv',
            rule: 'b',
            count: 1,
            severity: Severity.low,
            title: 'b',
          ),
        ]),
        config: const BaselineConfig(),
      ),
    );
    final FilterOutcome outcome = filter.apply(<Finding>[
      finding('a', Severity.low),
      finding('a', Severity.low),
      finding('b', Severity.low),
    ]);
    expect(outcome.kept.map((f) => f.ruleId), <String>['a']);
    expect(outcome.baselined.map((f) => f.ruleId), <String>['a']);
    expect(outcome.suppressed.map((f) => f.ruleId), <String>['b']);
  });

  test('keeps findings of unignorable severities whatever ignores them', () {
    final filter = FindingFilter(
      minSeverity: Severity.unknown,
      rules: <IgnoreRule>[const IgnoreRule(id: 'a', reason: 'r')],
      cliIgnores: const <String>['b'],
      now: DateTime.utc(2026),
      unignorable: const <Severity>{Severity.critical},
      baseline: BaselineMatcher(
        baseline: Baseline(const <BaselineEntry>[
          BaselineEntry(
            scope: BaselineScope.scan,
            source: 'osv',
            rule: 'c',
            count: 1,
            severity: Severity.critical,
            title: 'c',
          ),
        ]),
        config: const BaselineConfig(),
      ),
    );
    final FilterOutcome outcome = filter.apply(<Finding>[
      finding('a', Severity.critical),
      finding('a', Severity.high),
      finding('b', Severity.critical),
      finding('c', Severity.critical),
    ]);
    expect(outcome.kept.map((f) => f.ruleId), <String>['a', 'b', 'c']);
    expect(outcome.kept.map((f) => f.attributes['ignoreForbidden']), <Object?>[
      true,
      true,
      null,
    ]);
    expect(outcome.suppressed.single.severity, Severity.high);
    expect(outcome.baselined, isEmpty);
  });
}
