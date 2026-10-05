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

/// What the baseline did to the result of one check.
///
/// A check result carries a summary only when a baseline was applied, so
/// that the output of a package without a baseline does not change.
final class BaselineSummary {
  /// Creates a summary.
  const BaselineSummary({
    required this.covered,
    required this.stale,
    required this.failOnStale,
  });

  /// How many findings the baseline covered.
  final int covered;

  /// How many recorded findings no longer occur.
  final int stale;

  /// Whether stale entries fail the check (`baseline.fail_on_stale`).
  final bool failOnStale;

  /// Whether the check fails because of stale entries.
  bool get failed => failOnStale && stale > 0;

  /// Returns the lines that explain the summary, which are empty when there
  /// is nothing to say.
  List<String> render() => <String>[
    if (covered > 0) '  $covered finding(s) covered by the baseline.',
    if (stale > 0) _staleLine,
  ];

  /// The line that asks to prune the stale entries.
  String get _staleLine {
    final entries = stale == 1 ? 'entry is' : 'entries are';
    final failing = failOnStale ? ' (failing)' : '';
    return '  $stale baseline $entries fixed; run "inspectra baseline prune"'
        '$failing.';
  }

  /// Serializes the summary for the JSON report.
  ///
  /// Returns the JSON object.
  Map<String, Object?> toJson() => <String, Object?>{
    'covered': covered,
    'stale': stale,
  };
}
