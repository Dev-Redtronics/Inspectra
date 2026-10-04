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

/// Computes CVSS v2 base scores from vector strings such as
/// `AV:N/AC:L/Au:N/C:P/I:P/A:P`.
///
/// Older advisories only carry a v2 vector; the formula follows section
/// 3.2.1 of the CVSS v2 specification.
final class CvssV2Calculator {
  /// Creates a calculator.
  const CvssV2Calculator();

  /// Weights of the access vector metric.
  static const Map<String, double> _accessVector = <String, double>{
    'L': 0.395,
    'A': 0.646,
    'N': 1,
  };

  /// Weights of the access complexity metric.
  static const Map<String, double> _accessComplexity = <String, double>{
    'H': 0.35,
    'M': 0.61,
    'L': 0.71,
  };

  /// Weights of the authentication metric.
  static const Map<String, double> _authentication = <String, double>{
    'M': 0.45,
    'S': 0.56,
    'N': 0.704,
  };

  /// Weights of the confidentiality, integrity and availability metrics.
  static const Map<String, double> _impact = <String, double>{
    'N': 0,
    'P': 0.275,
    'C': 0.66,
  };

  /// Calculates the base score of [vector].
  ///
  /// Returns the score between `0.0` and `10.0`, or `null` when [vector] is
  /// not a complete CVSS v2 vector.
  double? baseScore(String vector) {
    final metrics = <String, String>{};
    final body = vector.startsWith('(') ? vector.substring(1) : vector;
    for (final part in body.replaceAll(')', '').split('/')) {
      final pair = part.split(':');
      if (pair.length == 2) {
        metrics[pair.first] = pair.last;
      }
    }
    final av = _accessVector[metrics['AV']];
    final ac = _accessComplexity[metrics['AC']];
    final au = _authentication[metrics['Au']];
    final c = _impact[metrics['C']];
    final i = _impact[metrics['I']];
    final a = _impact[metrics['A']];
    if (av == null || ac == null || au == null) {
      return null;
    }
    if (c == null || i == null || a == null) {
      return null;
    }
    final impact = 10.41 * (1 - (1 - c) * (1 - i) * (1 - a));
    final exploitability = 20 * av * ac * au;
    final factor = impact == 0 ? 0 : 1.176;
    final raw = ((0.6 * impact) + (0.4 * exploitability) - 1.5) * factor;
    final rounded = (raw * 10).round() / 10;
    return rounded < 0 ? 0 : rounded;
  }
}
