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

import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/model/source_location.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/style/style_result.dart';

/// The report of `inspectra style`.
///
/// Every violation is a finding of the source `style` with the severity
/// `LOW`, so that SARIF uploads show them as annotations; whether they fail
/// the command is decided by `style.fail_on_findings`, not by `--fail-on`.
final class StyleReport implements CommandReport {
  /// Creates the report of [result].
  const StyleReport(this.result);

  /// The outcome of the check.
  final StyleResult result;

  /// The name of the command.
  @override
  String get command => 'style';

  /// The violations as findings.
  @override
  List<Finding> get findings => <Finding>[
    for (final violation in result.violations)
      Finding(
        ruleId: violation.ruleId,
        source: FindingSource.style,
        severity: Severity.low,
        title: violation.message,
        location: SourceLocation(violation.path, line: violation.line),
      ),
  ];

  /// Whether the check failed; the severity [threshold] does not apply.
  ///
  /// Returns `true` when violations fail the check.
  @override
  bool isFailing(Severity threshold) => result.failed;

  /// Builds the JSON body.
  ///
  /// Returns the JSON body.
  @override
  Map<String, Object?> toJson() => result.toJson();

  /// Writes the summary and every violation.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    final String rendered = result.render();
    out.writeln(result.failed ? style.red(rendered) : rendered);
  }
}
