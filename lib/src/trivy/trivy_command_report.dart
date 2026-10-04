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
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/report/severity_breakdown.dart';
import 'package:inspectra/src/trivy/trivy_outcome.dart';
import 'package:inspectra/src/trivy/trivy_provision.dart';

/// The report of the `trivy` command.
final class TrivyCommandReport implements CommandReport {
  /// Creates a report for the scan of [target] with [outcome] and the
  /// policy filtered [findings]; [provisionOnly] marks `--install` and
  /// `--where` runs that did not scan.
  const TrivyCommandReport({
    required this.target,
    required this.outcome,
    required this.findings,
    this.provisionOnly = false,
  });

  /// The display path of the scanned directory.
  final String target;

  /// How Trivy was provisioned and what it reported.
  final TrivyOutcome outcome;

  /// The findings after ignore rules and severity filters.
  @override
  final List<Finding> findings;

  /// Whether only provisioning was requested.
  final bool provisionOnly;

  /// The name of the command.
  @override
  String get command => 'trivy';

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
    'target': target,
    'trivy': outcome.toJson(),
    'provisionOnly': provisionOnly,
  };

  /// Writes the human readable report.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    final String rule = style.dim('─' * 60);
    out
      ..writeln()
      ..writeln(
        '${style.bold('inspectra')}'
        '${style.dim(' — Trivy · $target')}',
      )
      ..writeln(rule);
    final TrivyProvision provision = outcome.provision;
    switch (provision) {
      case TrivyAvailable(:final executable, :final version, :final origin):
        out.writeln('  Trivy $version (${origin.id}): $executable');
      case TrivyUnavailable(:final reason):
        out.writeln(style.yellow('  ⚠ Trivy skipped: $reason'));
    }
    if (provisionOnly) {
      return;
    }
    out.writeln();
    for (final Finding finding in findings) {
      out
        ..writeln(
          '  ${style.severityLabel(finding.severity)}'
          '${style.bold(finding.ruleId)} ${style.dim('${finding.location}')}',
        )
        ..writeln('    ${finding.title}');
    }
    out
      ..writeln(rule)
      ..writeln(
        findings.isEmpty
            ? style.green('✔ No Trivy findings.')
            : 'Trivy findings: ${findings.length} '
                  '(${severityBreakdown(findings)})',
      );
  }
}
