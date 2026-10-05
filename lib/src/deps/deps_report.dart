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

import 'package:inspectra/src/deps/deps_result.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/report/severity_breakdown.dart';

/// The report of `deps`: the pubspec rules and the dependency policy.
///
/// The JSON body has `pubspecs`, `fixed` (one text per applied fix),
/// `suppressed` and `baselined` next to the `findings`.
final class DepsReport implements CommandReport {
  /// Creates the report of [result] with the policy filtered [findings];
  /// [suppressedCount] findings were removed by ignore rules and
  /// [baselinedCount] were covered by the baseline.
  const DepsReport({
    required this.result,
    required this.findings,
    this.suppressedCount = 0,
    this.baselinedCount = 0,
  });

  /// The raw outcome.
  final DepsResult result;

  /// The findings after ignore rules, severity filter and baseline.
  @override
  final List<Finding> findings;

  /// The number of findings removed by ignore rules.
  final int suppressedCount;

  /// The number of findings covered by the baseline.
  final int baselinedCount;

  /// The name of the command.
  @override
  String get command => 'deps';

  /// Fails when any finding reaches [threshold].
  ///
  /// Returns `true` when the command must exit with `1`.
  @override
  bool isFailing(Severity threshold) =>
      findings.any((finding) => finding.severity.isAtLeast(threshold));

  /// Builds the JSON body.
  ///
  /// Returns the JSON body.
  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'pubspecs': result.pubspecs,
    'fixed': result.fixes,
    'suppressed': suppressedCount,
    'baselined': baselinedCount,
  };

  /// Writes the human readable report.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    for (final String fix in result.fixes) {
      out.writeln(style.green('✔ Fixed $fix'));
    }
    for (final Finding finding in findings) {
      final String at = finding.location == null
          ? ''
          : style.dim('  ${finding.location}');
      out.writeln(
        '${style.severityLabel(finding.severity)}${finding.title}  '
        '${style.dim('(${finding.ruleId})')}$at',
      );
      if (finding.description.isNotEmpty) {
        out.writeln('    ${finding.description}');
      }
    }
    final notes = <String>[
      if (suppressedCount > 0) '$suppressedCount suppressed by ignore rules',
      if (baselinedCount > 0) '$baselinedCount covered by the baseline',
    ];
    final String note = notes.isEmpty
        ? ''
        : style.dim(' (${notes.join(', ')})');
    final checked = '${result.pubspecs.length} pubspec(s)';
    if (findings.isEmpty) {
      out.writeln(
        '${style.green('✔ The dependencies of $checked follow the rules.')}'
        '$note',
      );
      return;
    }
    out.writeln(
      '${style.bold('${findings.length} finding(s)')} in $checked: '
      '${severityBreakdown(findings)}$note',
    );
  }
}
