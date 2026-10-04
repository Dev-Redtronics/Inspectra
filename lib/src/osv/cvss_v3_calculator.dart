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

import 'dart:math';

/// Computes CVSS v3.0 and v3.1 base scores from vector strings.
///
/// OSV.dev publishes CVSS as vectors such as
/// `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H` and never as numbers, so a
/// tool that only parses numbers reports every vulnerability as "unknown".
/// This calculator implements the base score formula of the CVSS v3.1
/// specification, section 7.1, including its `Roundup` function.
final class CvssV3Calculator {
  /// Creates a calculator.
  const CvssV3Calculator();

  /// Weights of the attack vector metric.
  static const _attackVector = <String, double>{
    'N': 0.85,
    'A': 0.62,
    'L': 0.55,
    'P': 0.2,
  };

  /// Weights of the attack complexity metric.
  static const _attackComplexity = <String, double>{'L': 0.77, 'H': 0.44};

  /// Weights of the privileges required metric with unchanged scope.
  static const _privilegesUnchanged = <String, double>{
    'N': 0.85,
    'L': 0.62,
    'H': 0.27,
  };

  /// Weights of the privileges required metric with changed scope.
  static const _privilegesChanged = <String, double>{
    'N': 0.85,
    'L': 0.68,
    'H': 0.5,
  };

  /// Weights of the user interaction metric.
  static const _userInteraction = <String, double>{'N': 0.85, 'R': 0.62};

  /// Weights of the confidentiality, integrity and availability metrics.
  static const _impact = <String, double>{'H': 0.56, 'L': 0.22, 'N': 0};

  /// Calculates the base score of [vector].
  ///
  /// Returns the score between `0.0` and `10.0`, or `null` when [vector] is
  /// not a complete CVSS v3 vector.
  double? baseScore(String vector) {
    if (!vector.startsWith('CVSS:3.')) {
      return null;
    }
    final Map<String, String> metrics = _parse(vector);
    final scopeChanged = metrics['S'] == 'C';
    final Map<String, double> privileges = scopeChanged
        ? _privilegesChanged
        : _privilegesUnchanged;
    final double? av = _attackVector[metrics['AV']];
    final double? ac = _attackComplexity[metrics['AC']];
    final double? pr = privileges[metrics['PR']];
    final double? ui = _userInteraction[metrics['UI']];
    final double? c = _impact[metrics['C']];
    final double? i = _impact[metrics['I']];
    final double? a = _impact[metrics['A']];
    final String? scope = metrics['S'];
    if (av == null || ac == null || pr == null || ui == null) {
      return null;
    }
    if (c == null || i == null || a == null || scope == null) {
      return null;
    }
    final double iss = 1 - ((1 - c) * (1 - i) * (1 - a));
    final double impact = scopeChanged
        ? 7.52 * (iss - 0.029) - 3.25 * pow(iss - 0.02, 15)
        : 6.42 * iss;
    if (impact <= 0) {
      return 0;
    }
    final double exploitability = 8.22 * av * ac * pr * ui;
    final double combined = scopeChanged
        ? 1.08 * (impact + exploitability)
        : impact + exploitability;
    return roundUp(min(combined, 10));
  }

  /// The CVSS v3.1 `Roundup` function: the smallest number with one decimal
  /// that is equal to or higher than [value], robust against floating point
  /// artefacts.
  ///
  /// Returns the rounded value.
  static double roundUp(double value) {
    final int scaled = (value * 100000).round();
    if (scaled % 10000 == 0) {
      return scaled / 100000;
    }
    return ((scaled ~/ 10000) + 1) / 10;
  }

  /// Splits [vector] into its metric values keyed by metric name.
  ///
  /// Returns the metrics; malformed parts are ignored.
  static Map<String, String> _parse(String vector) {
    final metrics = <String, String>{};
    for (final String part in vector.split('/').skip(1)) {
      final List<String> pair = part.split(':');
      if (pair.length == 2) {
        metrics[pair.first] = pair.last;
      }
    }
    return metrics;
  }
}
