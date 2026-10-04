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
import 'package:inspectra/src/inspect/risk_scorer.dart';
import 'package:test/test.dart';

/// Tests the risk score.
void main() {
  /// Creates a finding of [source] with [severity] in [path].
  Finding finding(FindingSource source, Severity severity, String path) =>
      Finding(
        ruleId: 'R',
        source: source,
        severity: severity,
        title: 't',
        location: SourceLocation(path),
      );

  test('uses the dart_audit weights and counts each rule and file once', () {
    final int score = const RiskScorer().score(<Finding>[
      finding(FindingSource.regex, Severity.high, 'a.dart'),
      finding(FindingSource.regex, Severity.high, 'a.dart'),
      finding(FindingSource.entropy, Severity.medium, 'b.dart'),
    ]);
    expect(score, 25);
  });

  test('caps the score at 100 and labels it', () {
    final findings = <Finding>[
      for (var i = 0; i < 5; i++)
        finding(FindingSource.regex, Severity.critical, '$i.dart'),
    ];
    expect(const RiskScorer().score(findings), 100);
    expect(const RiskScorer().label(0), 'CLEAN');
    expect(const RiskScorer().label(29), 'LOW RISK');
    expect(const RiskScorer().label(30), 'SUSPICIOUS');
    expect(const RiskScorer().label(60), 'HIGH RISK');
  });
}
