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
}
