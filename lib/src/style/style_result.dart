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

import 'package:inspectra/src/style/style_violation.dart';

/// The outcome of the style check.
final class StyleResult {
  /// Creates the outcome of checking [checked] files with the [rules],
  /// which found [violations]; [failOnFindings] decides whether they fail.
  StyleResult({
    required this.checked,
    required this.rules,
    required List<StyleViolation> violations,
    required this.failOnFindings,
  }) : violations = List<StyleViolation>.unmodifiable(violations);

  /// The number of checked files.
  final int checked;

  /// The ids of the rules that ran.
  final List<String> rules;

  /// Every violation, sorted by path, line, column and rule.
  final List<StyleViolation> violations;

  /// Whether violations fail the check.
  final bool failOnFindings;

  /// Whether the check failed.
  bool get failed => failOnFindings && violations.isNotEmpty;

  /// The number of files with at least one violation.
  int get affectedFiles => violations.map((v) => v.path).toSet().length;

  /// A readable summary for the console.
  ///
  /// Returns the summary.
  String render() {
    final count = '${rules.length} rule(s)';
    if (violations.isEmpty) {
      return 'Style: all $checked file(s) follow the $count.';
    }
    final suffix = failed ? '' : ' (not failing)';
    final summary =
        'Style: ${violations.length} violation(s) in $affectedFiles of '
        '$checked file(s)$suffix.';
    const hint =
        'Fix them, or suppress a single line with '
        '"// inspectra: ignore-style <rule>".';
    return <String>[
      summary,
      for (final violation in violations) '  $violation',
      hint,
    ].join('\n');
  }

  /// Serialises the result for the report file and JSON output.
  ///
  /// Returns the JSON object.
  Map<String, Object?> toJson() => <String, Object?>{
    'check': 'style',
    'failed': failed,
    'checked': checked,
    'rules': rules,
    'violations': <Map<String, Object?>>[
      for (final violation in violations) violation.toJson(),
    ],
  };
}
