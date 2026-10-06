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
import 'package:inspectra/src/baseline/baseline_candidates.dart';
import 'package:inspectra/src/baseline/baseline_entry.dart';
import 'package:inspectra/src/baseline/baseline_match.dart';
import 'package:inspectra/src/baseline/baseline_matcher.dart';
import 'package:inspectra/src/baseline/baseline_scope.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/fixtures.dart';

/// Tests which findings a baseline covers.
void main() {
  /// Creates a `no_else` violation in [path] at [line].
  StyleViolation violation(String path, int line) => StyleViolation(
    ruleId: 'no_else',
    path: path,
    line: line,
    column: 1,
    message: 'No else.',
  );

  /// Creates a matcher of a baseline covering [count] `no_else` violations
  /// in `lib/a.dart`, with the settings [config].
  BaselineMatcher matcher({
    int count = 1,
    BaselineConfig config = const BaselineConfig(),
  }) => BaselineMatcher(
    baseline: Baseline(<BaselineEntry>[
      BaselineEntry(
        scope: BaselineScope.style,
        source: styleSource,
        rule: 'no_else',
        count: count,
        severity: Severity.low,
        title: 'No else.',
        path: 'lib/a.dart',
      ),
    ]),
    config: config,
  );

  /// Selects the entries of the style scope.
  bool styleOnly(BaselineEntry entry) => entry.scope == BaselineScope.style;

  test('covers up to the recorded count, in the order of the lines', () {
    final BaselineMatch<StyleViolation> match = matcher(count: 2)
        .partition(<StyleViolation>[
          violation('lib/a.dart', 30),
          violation('lib/b.dart', 1),
          violation('lib/a.dart', 4),
          violation('lib/a.dart', 12),
        ], styleCandidate);
    expect(match.baselined.map((v) => v.line), <int>[4, 12]);
    expect(match.kept.map((v) => '${v.path}:${v.line}'), <String>[
      'lib/a.dart:30',
      'lib/b.dart:1',
    ]);
    expect(match.stale, 0);
  });

  test('keeps covering a finding whose line moved', () {
    final BaselineMatch<StyleViolation> match = matcher().partition(
      <StyleViolation>[violation('lib/a.dart', 120)],
      styleCandidate,
    );
    expect(match.kept, isEmpty);
    expect(match.baselined, hasLength(1));
  });

  test('never covers findings above max_severity', () {
    final BaselineMatch<StyleViolation> low = matcher(
      config: const BaselineConfig(maxSeverity: Severity.low),
    ).partition(<StyleViolation>[violation('lib/a.dart', 1)], styleCandidate);
    expect(low.baselined, hasLength(1));
    final BaselineMatch<StyleViolation> unknown = matcher(
      config: const BaselineConfig(maxSeverity: Severity.unknown),
    ).partition(<StyleViolation>[violation('lib/a.dart', 1)], styleCandidate);
    expect(unknown.kept, hasLength(1));
    expect(unknown.stale, 0);
  });

  test('never covers findings of severities a policy protects', () {
    final protected = BaselineMatcher(
      baseline: matcher().baseline,
      config: const BaselineConfig(),
      unignorable: const <Severity>{Severity.low},
    );
    final BaselineMatch<StyleViolation> match = protected.partition(
      <StyleViolation>[violation('lib/a.dart', 1)],
      styleCandidate,
    );
    expect(match.kept, hasLength(1));
    expect(match.baselined, isEmpty);
  });

  test('counts fixed findings as stale only for checked entries', () {
    final BaselineMatcher three = matcher(count: 3);
    final current = <StyleViolation>[violation('lib/a.dart', 1)];
    expect(three.partition(current, styleCandidate).stale, 0);
    final BaselineMatch<StyleViolation> checked = three.partition(
      current,
      styleCandidate,
      checked: styleOnly,
    );
    expect(checked.stale, 2);
    expect(three.summarize(checked).failed, isFalse);
    final BaselineMatcher strict = matcher(
      count: 3,
      config: const BaselineConfig(failOnStale: true),
    );
    expect(
      strict
          .summarize(
            strict.partition(current, styleCandidate, checked: styleOnly),
          )
          .failed,
      isTrue,
    );
  });

  test('loads the configured file unless the baseline is disabled', () {
    final String root = temporaryDirectory();
    matcher().baseline.write(p.join(root, 'custom.json'));
    final loaded = BaselineMatcher.load(
      const BaselineConfig(file: 'custom.json'),
      root,
    );
    expect(loaded.isEmpty, isFalse);
    final disabled = BaselineMatcher.load(
      const BaselineConfig(enabled: false, file: 'custom.json'),
      root,
    );
    expect(disabled.isEmpty, isTrue);
    expect(BaselineMatcher.load(const BaselineConfig(), root).isEmpty, isTrue);
  });
}
