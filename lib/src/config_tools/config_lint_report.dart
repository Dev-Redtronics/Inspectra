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

import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/report/severity_breakdown.dart';

/// The report of `config lint`: risky settings of the configuration.
///
/// The JSON body has `source`, the configuration file or `null`, and
/// `suppressed`, the findings removed by ignore rules, next to the
/// `findings`.
final class ConfigLintReport implements CommandReport {
  /// Creates the report of the [findings] about the configuration read from
  /// [source]; [suppressedCount] findings were removed by ignore rules.
  const ConfigLintReport({
    required this.findings,
    required this.source,
    required this.suppressedCount,
  });

  /// The findings after ignore rules and severity filters.
  @override
  final List<Finding> findings;

  /// The configuration file, or `null` without one.
  final String? source;

  /// The number of suppressed findings.
  final int suppressedCount;

  /// The name of the command.
  @override
  String get command => 'config lint';

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
    'source': source,
    'suppressed': suppressedCount,
  };

  /// Writes the human readable report.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    final String where = source ?? 'the built-in defaults';
    final String suppressed = suppressedCount == 0
        ? ''
        : style.dim(' ($suppressedCount suppressed by ignore rules)');
    if (findings.isEmpty) {
      out.writeln(
        '${style.green('✔ The configuration of $where has no risky '
        'settings.')}$suppressed',
      );
      return;
    }
    for (final Finding finding in findings) {
      final String at = finding.location == null
          ? ''
          : style.dim('  ${finding.location}');
      out
        ..writeln(
          '${style.severityLabel(finding.severity)}${finding.title}  '
          '${style.dim('(${finding.ruleId})')}$at',
        )
        ..writeln('    ${finding.description}');
    }
    out.writeln(
      '${style.bold('${findings.length} finding(s)')} in the configuration '
      'of $where: ${severityBreakdown(findings)}$suppressed',
    );
  }
}
