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
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/severity.dart';

/// Turns inspection findings into a 0–100 risk score and label.
///
/// The weights are fixed, so scores remain comparable between runs. Two
/// measures stop a single noisy rule from saturating the score: each
/// combination of rule and file counts only once, and severities without a
/// weight count zero.
final class RiskScorer {
  /// Creates a scorer.
  const RiskScorer();

  /// Points per source and severity.
  static const _weights = <FindingSource, Map<Severity, int>>{
    FindingSource.regex: <Severity, int>{
      Severity.critical: 40,
      Severity.high: 20,
      Severity.medium: 10,
      Severity.low: 5,
      Severity.unknown: 5,
    },
    FindingSource.entropy: <Severity, int>{
      Severity.high: 15,
      Severity.medium: 5,
    },
    FindingSource.unicode: <Severity, int>{
      Severity.critical: 35,
      Severity.high: 15,
    },
    FindingSource.archive: <Severity, int>{
      Severity.critical: 30,
      Severity.high: 10,
      Severity.medium: 5,
    },
    FindingSource.trust: <Severity, int>{
      Severity.critical: 25,
      Severity.high: 10,
      Severity.medium: 3,
    },
    FindingSource.pubspec: <Severity, int>{
      Severity.critical: 30,
      Severity.high: 10,
      Severity.medium: 3,
    },
  };

  /// Computes the score of [findings].
  ///
  /// Returns a value between `0` and `100`.
  int score(List<Finding> findings) {
    final counted = <String>{};
    var total = 0;
    for (final finding in findings) {
      final key =
          '${finding.source.id}|${finding.ruleId}|'
          '${finding.location?.path ?? ''}';
      if (!counted.add(key)) {
        continue;
      }
      total += _weights[finding.source]?[finding.severity] ?? 0;
    }
    return total > 100 ? 100 : total;
  }

  /// Returns the label of [score]: `CLEAN`, `LOW RISK`, `SUSPICIOUS` or
  /// `HIGH RISK`.
  String label(int score) {
    if (score == 0) {
      return 'CLEAN';
    }
    if (score < 30) {
      return 'LOW RISK';
    }
    if (score < 60) {
      return 'SUSPICIOUS';
    }
    return 'HIGH RISK';
  }
}
