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

import 'package:inspectra/src/config/hook_check.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/report/severity_breakdown.dart';

/// The report of `hook run`: the checks of `hook.checks` on the staged
/// files.
///
/// The JSON body has `checks`, the checks that ran, `staged`, the staged
/// files they looked at, and `partiallyStaged`, the Dart files whose
/// working tree differs from the index.
final class HookRunReport implements CommandReport {
  /// Creates the report of the [checks] that looked at the [staged] files
  /// and found [findings]; [partiallyStaged] files were checked as they
  /// are in the working tree.
  const HookRunReport({
    required this.checks,
    required this.staged,
    required this.findings,
    this.partiallyStaged = const <String>[],
  });

  /// The checks that ran.
  final List<HookCheck> checks;

  /// The staged files the checks looked at.
  final List<String> staged;

  /// The findings after ignore rules, severity filter and baseline.
  @override
  final List<Finding> findings;

  /// The Dart files that also have unstaged changes.
  final List<String> partiallyStaged;

  /// The name of the command.
  @override
  String get command => 'hook run';

  /// Fails when a finding reaches [threshold]; typosquatting and
  /// dependency confusion fail from `high`, as the `typosquat` command
  /// does.
  ///
  /// Returns `true` when the commit must be stopped.
  @override
  bool isFailing(Severity threshold) => findings.any((finding) {
    final bool lookalike =
        finding.source == FindingSource.typosquat ||
        finding.source == FindingSource.confusion;
    final Severity applied = lookalike && threshold.rank > Severity.high.rank
        ? Severity.high
        : threshold;
    return finding.severity.isAtLeast(applied);
  });

  /// Builds the JSON body.
  ///
  /// Returns the JSON body.
  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'checks': <String>[for (final check in checks) check.id],
    'staged': staged,
    'partiallyStaged': partiallyStaged,
  };

  /// Writes the findings and a summary.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    for (final String path in partiallyStaged) {
      out.writeln(
        style.yellow(
          '! $path has unstaged changes; format checked the working tree.',
        ),
      );
    }
    for (final Finding finding in findings) {
      final String at = finding.location == null
          ? ''
          : style.dim('  ${finding.location}');
      out.writeln(
        '${style.severityLabel(finding.severity)}${finding.title}  '
        '${style.dim('(${finding.ruleId})')}$at',
      );
    }
    final String names = checks.map((check) => check.id).join(', ');
    if (findings.isEmpty) {
      out.writeln(
        style.green(
          '✔ $names: ${staged.length} staged file(s) pass the pre-commit '
          'checks.',
        ),
      );
      return;
    }
    out.writeln(
      '${style.bold('${findings.length} finding(s)')} in the staged files '
      '($names): ${severityBreakdown(findings)}. Bypass once with '
      '"git commit --no-verify".',
    );
  }
}
