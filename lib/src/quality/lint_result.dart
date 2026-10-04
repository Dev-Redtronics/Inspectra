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

import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/quality/lint.dart';

/// The outcome of the static analysis check.
class LintResult {
  /// Creates the outcome.
  LintResult({required List<LintIssue> issues, required this.failOn})
    : issues = List.unmodifiable(
        <LintIssue>[...issues]..sort((a, b) {
          final int bySeverity = a.severity.index.compareTo(b.severity.index);
          if (bySeverity != 0) {
            return bySeverity;
          }
          final int byPath = a.path.compareTo(b.path);
          if (byPath != 0) {
            return byPath;
          }
          final int byLine = a.line.compareTo(b.line);
          return byLine != 0 ? byLine : a.column.compareTo(b.column);
        }),
      );

  /// Every diagnostic, errors first, then by file and position.
  final List<LintIssue> issues;

  /// The lowest severity that fails the check.
  final LintLevel failOn;

  /// The diagnostics that fail the check.
  Iterable<LintIssue> get failing =>
      issues.where((issue) => issue.severity.index <= failOn.index);

  /// Whether the check failed.
  bool get failed => failOn != LintLevel.none && failing.isNotEmpty;

  /// A readable summary for the console or the build log.
  String render() {
    if (issues.isEmpty) {
      return 'Lint: no issues found.';
    }
    String count(LintLevel level) =>
        '${issues.where((issue) => issue.severity == level).length} '
        '${level.name}(s)';
    final suffix = failed ? '' : ' (not failing)';
    final String counts = [
      LintLevel.error,
      LintLevel.warning,
      LintLevel.info,
    ].map(count).join(', ');
    return [
      'Lint: ${issues.length} issue(s) - $counts$suffix.',
      for (final issue in issues) _render(issue),
    ].join('\n');
  }

  /// Renders [issue] as one indented line with its level, location, code and
  /// message.
  static String _render(LintIssue issue) {
    final String level = issue.severity.name.toUpperCase();
    final location = '${issue.path}:${issue.line}:${issue.column}';
    return '  [$level] $location: ${issue.code} - ${issue.message}';
  }

  /// Serializes this result for the JSON report.
  Map<String, Object?> toJson() => {
    'check': 'lint',
    'failed': failed,
    'fail_on': failOn.name,
    'issues': [for (final issue in issues) issue.toJson()],
  };
}
