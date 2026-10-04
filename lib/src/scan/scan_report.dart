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
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/report/severity_breakdown.dart';
import 'package:inspectra/src/scan/scan_result.dart';

/// The report of the `scan` command, the default command.
final class ScanReport implements CommandReport {
  /// Creates a report for [result] with the policy filtered [findings];
  /// [suppressedCount] findings were removed by ignore rules.
  const ScanReport({
    required this.result,
    required this.findings,
    required this.suppressedCount,
  });

  /// The raw scan outcome.
  final ScanResult result;

  /// The findings after ignore rules and severity filters.
  @override
  final List<Finding> findings;

  /// The number of suppressed findings.
  final int suppressedCount;

  /// The name of the command.
  @override
  String get command => 'scan';

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
  Map<String, Object?> toJson() {
    final int scanned = result.audits.fold<int>(
      0,
      (sum, audit) => sum + audit.scanned.length,
    );
    return <String, Object?>{
      'root': result.root,
      'lockfiles': result.audits.map((audit) => audit.lockfilePath).toList(),
      'pubspecs': result.pubspecs,
      'scanned': scanned,
      'skipped': result.audits.fold<int>(
        0,
        (sum, audit) => sum + audit.skipped.length,
      ),
      'confusionChecked': result.confusionChecked,
      'trivy': result.trivy.toJson(),
      'suppressed': suppressedCount,
      'summary': <String, Object?>{
        for (final severity in Severity.values)
          severity.name: findings
              .where((finding) => finding.severity == severity)
              .length,
      },
    };
  }

  /// Writes the human readable report.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    final String rule = style.dim('─' * 60);
    final int scanned = result.audits.fold<int>(
      0,
      (sum, audit) => sum + audit.scanned.length,
    );
    out
      ..writeln()
      ..writeln(
        '${style.bold('inspectra')}${style.dim(' — project scan · '
        '${result.root} · ${result.audits.length} lockfile(s), $scanned '
        'packages')}',
      )
      ..writeln(rule);
    final sections = <(String, bool Function(Finding))>[
      (
        'Known vulnerabilities',
        (f) =>
            f.source == FindingSource.osv ||
            f.attributes['kind'] == 'vulnerability',
      ),
      (
        'Supply chain',
        (f) => const <FindingSource>{
          FindingSource.typosquat,
          FindingSource.confusion,
          FindingSource.pubspec,
        }.contains(f.source),
      ),
      ('Secrets', (f) => f.attributes['kind'] == 'secret'),
      ('Misconfigurations', (f) => f.attributes['kind'] == 'misconfiguration'),
      ('Licenses', (f) => f.attributes['kind'] == 'license'),
    ];
    for (final (title, predicate) in sections) {
      _section(out, style, title, findings.where(predicate).toList());
    }
    _writeTrivyStatus(out, style);
    out.writeln(rule);
    _writeSummary(out, style);
  }

  /// Writes one titled section.
  void _section(
    StringBuffer out,
    AnsiStyler style,
    String title,
    List<Finding> sectionFindings,
  ) {
    if (sectionFindings.isEmpty) {
      return;
    }
    out.writeln(style.bold('$title (${sectionFindings.length}):'));
    for (final finding in sectionFindings) {
      final String package = finding.packageName == null
          ? ''
          : ' ${finding.packageName} ${finding.packageVersion ?? ''}'
                .trimRight();
      out
        ..writeln(
          '  ${style.severityLabel(finding.severity)}'
          '${style.bold(finding.ruleId)}$package '
          '${style.dim('[${finding.source.id}] ${finding.location ?? ''}')}',
        )
        ..writeln('    ${finding.title}');
      final String? fixed = finding.fixedVersion;
      if (fixed != null) {
        out.writeln('    ${style.green('Fix:')} upgrade to $fixed');
      }
    }
    out.writeln();
  }

  /// Writes whether Trivy ran.
  void _writeTrivyStatus(StringBuffer out, AnsiStyler style) {
    final Map<String, Object?> trivy = result.trivy.toJson();
    if (trivy['status'] == 'ran') {
      out.writeln(
        style.dim(
          'Trivy ${trivy['version']} '
          '(${trivy['origin']}) scanned ${result.root}.',
        ),
      );
      return;
    }
    out.writeln(style.yellow('⚠ Trivy skipped: ${trivy['reason']}'));
  }

  /// Writes the closing summary.
  void _writeSummary(StringBuffer out, AnsiStyler style) {
    final String suppressed = suppressedCount == 0
        ? ''
        : style.dim(' ($suppressedCount suppressed by ignore rules)');
    if (findings.isEmpty) {
      out.writeln('${style.green(style.bold('✔ No findings.'))}$suppressed');
      return;
    }
    out.writeln(
      '${style.red(style.bold('${findings.length} finding(s):'))} '
      '${severityBreakdown(findings)}$suppressed',
    );
  }
}
