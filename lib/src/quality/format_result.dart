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

/// The outcome of the formatting check.
class FormatResult {
  /// Creates the outcome for [checked] files, of which [unformatted] are not
  /// formatted.
  FormatResult({
    required this.checked,
    required List<String> unformatted,
    required this.failOnFindings,
    this.fixed = false,
  }) : unformatted = List.unmodifiable(unformatted..sort());

  /// How many files were checked.
  final int checked;

  /// The files that are not formatted, relative to the package root - or,
  /// when [fixed], the files that were formatted.
  final List<String> unformatted;

  /// Whether unformatted files fail the check.
  final bool failOnFindings;

  /// Whether the files were formatted in place instead of checked.
  final bool fixed;

  /// Whether the check failed.
  bool get failed => !fixed && failOnFindings && unformatted.isNotEmpty;

  /// A readable summary for the console or the build log.
  String render() {
    if (fixed) {
      return unformatted.isEmpty
          ? 'Format: all $checked file(s) were already formatted.'
          : 'Format: formatted ${unformatted.length} of $checked file(s).\n'
                '${unformatted.map((path) => '  $path').join('\n')}';
    }
    if (unformatted.isEmpty) {
      return 'Format: all $checked file(s) are formatted.';
    }
    final suffix = failed ? '' : ' (not failing)';
    final count = '${unformatted.length} of $checked file(s)';
    return [
      'Format: $count are not formatted$suffix.',
      for (final path in unformatted) '  $path',
      'Run "dart run inspectra format --fix" or "dart format ." to fix them.',
    ].join('\n');
  }

  /// Serializes this result for the JSON report.
  Map<String, Object?> toJson() => {
    'check': 'format',
    'failed': failed,
    'fixed': fixed,
    'checked': checked,
    'unformatted': unformatted,
  };
}
