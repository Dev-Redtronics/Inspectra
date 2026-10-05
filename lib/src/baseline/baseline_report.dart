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

import 'package:inspectra/src/baseline/baseline.dart';
import 'package:inspectra/src/baseline/baseline_scope.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/command_report.dart';

/// The report of `baseline create` and `baseline prune`.
///
/// The JSON body has the fields `action`, `file`, `changed`, `total` and
/// `scopes`, one object per scope that ran with the recorded findings
/// `before` and `after`.
final class BaselineReport implements CommandReport {
  /// Creates the report of the [action] (`create` or `prune`) on the
  /// baseline file [file], which held [before] and now holds [after]; the
  /// [scopes] ran and [changed] tells whether the file was written.
  const BaselineReport({
    required this.action,
    required this.file,
    required this.scopes,
    required this.before,
    required this.after,
    required this.changed,
  });

  /// The performed action, `create` or `prune`.
  final String action;

  /// The baseline file, relative to the working directory.
  final String file;

  /// The scopes whose findings were collected.
  final List<BaselineScope> scopes;

  /// The baseline before the action.
  final Baseline before;

  /// The baseline after the action.
  final Baseline after;

  /// Whether the baseline file was written.
  final bool changed;

  /// The name of the command.
  @override
  String get command => 'baseline $action';

  /// Recording a baseline never reports findings.
  @override
  List<Finding> get findings => const <Finding>[];

  /// Recording a baseline never fails because of findings.
  ///
  /// Returns `false`.
  @override
  bool isFailing(Severity threshold) => false;

  /// Builds the JSON body.
  ///
  /// Returns the JSON body.
  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'action': action,
    'file': file,
    'changed': changed,
    'total': _total(after),
    'scopes': <Map<String, Object?>>[
      for (final scope in scopes)
        <String, Object?>{
          'scope': scope.id,
          'before': before.countOf(scope),
          'after': after.countOf(scope),
        },
    ],
  };

  /// Writes the human readable report.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    final int total = _total(after);
    final String headline = changed
        ? style.green('✔ Baseline $file updated: $total finding(s) recorded.')
        : 'Baseline $file unchanged: $total finding(s) recorded.';
    out.writeln(headline);
    for (final BaselineScope scope in scopes) {
      out.writeln(
        '  ${scope.id}: ${after.countOf(scope)} '
        '(was ${before.countOf(scope)})',
      );
    }
  }

  /// Returns the number of findings [baseline] records over every scope.
  static int _total(Baseline baseline) => BaselineScope.values.fold(
    0,
    (sum, scope) => sum + baseline.countOf(scope),
  );
}
