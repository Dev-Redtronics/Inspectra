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

import '../inspect/inspection_report.dart';
import '../io/ansi_styler.dart';
import '../model/finding.dart';
import '../model/finding_source.dart';
import '../model/severity.dart';
import '../report/command_report.dart';

/// The report of the `add` command.
final class AddReport implements CommandReport {
  /// Creates a report.
  ///
  /// [inspection] holds the source and trust inspection, [blockReasons] the
  /// reasons why the package was not considered safe, [installed] whether
  /// `pub add` ran successfully, [forced] whether `--force` overrode the
  /// block, [dryRun] whether installation was skipped on purpose and
  /// [pubOutput] the output of `pub add`.
  const AddReport({
    required this.package,
    required this.version,
    required this.dev,
    required this.inspection,
    required this.blockReasons,
    required this.installed,
    required this.forced,
    required this.dryRun,
    this.pubOutput = '',
  });

  /// The package name.
  final String package;

  /// The exact version that was inspected and installed.
  final String version;

  /// Whether the package was added as a development dependency.
  final bool dev;

  /// The inspection of the package.
  final InspectionReport inspection;

  /// Why the package was blocked; empty when it passed every check.
  final List<String> blockReasons;

  /// Whether the package was installed.
  final bool installed;

  /// Whether `--force` overrode the block.
  final bool forced;

  /// Whether installation was skipped because of `--dry-run`.
  final bool dryRun;

  /// The output of `pub add`.
  final String pubOutput;

  /// Whether the security audit blocked the package.
  bool get blocked => blockReasons.isNotEmpty;

  /// The name of the command.
  @override
  String get command => 'add';

  /// All findings of the inspection, including typosquat findings.
  @override
  List<Finding> get findings => inspection.findings;

  /// Fails when the package was blocked and not installed.
  ///
  /// Returns `true` when the command must exit with `1`.
  @override
  bool isFailing(Severity threshold) => blocked && !installed;

  /// Builds the JSON body.
  ///
  /// Returns the JSON body.
  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'package': package,
      'version': version,
      'dev': dev,
      'installed': installed,
      'blocked': blocked,
      'blockReasons': blockReasons,
      'forced': forced,
      'dryRun': dryRun,
      'riskScore': inspection.riskScore,
      'riskLabel': inspection.riskLabel,
      'inspection': inspection.toJson(),
      'findings': findings.map((finding) => finding.toJson()).toList(),
    };
  }

  /// Writes the human readable report.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    final typosquat = findings.where(
      (finding) => finding.source == FindingSource.typosquat,
    );
    if (typosquat.isNotEmpty) {
      out.writeln('\n  ${style.bold('Typosquatting Risk:')}');
      for (final finding in typosquat) {
        out.writeln(
          '  ${style.severityLabel(finding.severity)}'
          '${finding.title}',
        );
      }
    }
    inspection.writeText(out, style);
    out.writeln();
    for (final reason in blockReasons) {
      out.writeln('${style.red('[BLOCKED]')} $reason');
    }
    if (pubOutput.trim().isNotEmpty) {
      out.writeln(style.dim(pubOutput.trim()));
    }
    out.writeln(_verdict(style));
  }

  /// Formats the final verdict line.
  ///
  /// Returns the styled verdict.
  String _verdict(AnsiStyler style) {
    if (installed && forced && blocked) {
      return style.yellow(
        '⚠ Package "$package" $version was added despite '
        'the findings above (--force).',
      );
    }
    if (installed) {
      return style.green(
        '✔ Package "$package" $version passed the security '
        'audit and was added.',
      );
    }
    if (dryRun && !blocked) {
      return style.green(
        '✔ Package "$package" $version passed the security '
        'audit (dry run, not added).',
      );
    }
    return style.red(
      '✖ Package "$package" $version was not added. Review '
      'the findings or use --force to add it anyway.',
    );
  }
}
