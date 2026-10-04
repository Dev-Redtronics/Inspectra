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

import 'package:inspectra/src/audit/audit_scan.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/pub/lockfile_entry.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/report/severity_breakdown.dart';

/// The report of the `audit` command.
///
/// Its JSON body keeps the `dart_audit` fields `scanned`,
/// `vulnerablePackages`, `totalVulnerabilities` and `results`, and adds
/// `lockfile`, `skipped` and `suppressed`.
final class AuditReport implements CommandReport {
  /// Creates a report for [scan], whose policy filtered findings are
  /// [findings]; [suppressedCount] findings were ignored by rules and
  /// [verbose] lists clean packages too.
  const AuditReport({
    required this.scan,
    required this.findings,
    required this.suppressedCount,
    this.verbose = false,
  });

  /// The raw audit outcome.
  final AuditScan scan;

  /// The findings after ignore rules and severity filters.
  @override
  final List<Finding> findings;

  /// How many findings were suppressed by ignore rules.
  final int suppressedCount;

  /// Whether clean packages are listed in the text report.
  final bool verbose;

  /// The name of the command.
  @override
  String get command => 'audit';

  /// The findings of [package].
  ///
  /// Returns the findings in report order.
  List<Finding> _findingsOf(LockfileEntry package) => findings
      .where((f) => f.packageName == package.name)
      .where((f) => f.packageVersion == package.version)
      .toList();

  /// The scanned packages with at least one finding.
  List<LockfileEntry> get vulnerablePackages =>
      scan.scanned.where((pkg) => _findingsOf(pkg).isNotEmpty).toList();

  /// Fails when any finding reaches [threshold].
  ///
  /// Returns `true` when the command must exit with `1`.
  @override
  bool isFailing(Severity threshold) =>
      findings.any((finding) => finding.severity.isAtLeast(threshold));

  /// Builds the `dart_audit` compatible JSON body.
  ///
  /// Returns the JSON body.
  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'lockfile': scan.lockfilePath,
    'scanned': scan.scanned.length,
    'vulnerablePackages': vulnerablePackages.length,
    'totalVulnerabilities': findings.length,
    'suppressed': suppressedCount,
    'results': <Object?>[
      for (final package in scan.scanned)
        <String, Object?>{
          'name': package.name,
          'version': package.version,
          'isDirect': package.isDirect,
          'vulnerabilities': _findingsOf(package).map(_vulnerability).toList(),
        },
    ],
    'skipped': <Object?>[
      for (final package in scan.skipped)
        <String, Object?>{
          'name': package.name,
          'version': package.version,
          'source': package.source,
        },
    ],
  };

  /// Serialises one advisory finding in the `dart_audit` layout.
  ///
  /// Returns the JSON object.
  Map<String, Object?> _vulnerability(Finding finding) => <String, Object?>{
    'id': finding.ruleId,
    'summary': finding.title,
    'severity': finding.severity.name,
    'fixedVersion': finding.fixedVersion,
    'aliases': finding.aliases,
    'detailsUrl': finding.url,
  };

  /// Writes the human readable report.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    final String rule = style.dim('─' * 60);
    out
      ..writeln()
      ..writeln(
        '${style.bold('inspectra')}${style.dim(' — OSV.dev audit · '
        '${scan.lockfilePath} · ${scan.scanned.length} packages checked')}',
      )
      ..writeln(rule);
    _writeSkipped(out, style);
    final List<LockfileEntry> vulnerable = vulnerablePackages;
    if (vulnerable.isEmpty) {
      out.writeln(
        style.green(
          '✔ No known vulnerabilities found in '
          '${scan.scanned.length} packages.',
        ),
      );
    }
    for (final package in vulnerable) {
      _writePackage(out, style, package);
    }
    _writeClean(out, style);
    out.writeln(rule);
    _writeSummary(out, style, vulnerable.length);
  }

  /// Writes the list of packages that could not be audited.
  void _writeSkipped(StringBuffer out, AnsiStyler style) {
    if (scan.skipped.isEmpty) {
      return;
    }
    out.writeln(
      style.yellow(
        '⚠ ${scan.skipped.length} package(s) skipped '
        '(git/path/sdk/private registry — not covered by OSV.dev):',
      ),
    );
    for (final LockfileEntry package in scan.skipped) {
      out.writeln(style.dim('  · ${package.name} (${package.source})'));
    }
    out.writeln();
  }

  /// Writes the advisories of one vulnerable [package].
  void _writePackage(
    StringBuffer out,
    AnsiStyler style,
    LockfileEntry package,
  ) {
    final kind = package.isDirect ? ' (direct)' : ' (transitive)';
    out.writeln(
      '${style.bold(package.name)} ${package.version}'
      '${style.dim(kind)}',
    );
    for (final Finding finding in _findingsOf(package)) {
      final String aliases = finding.aliases.isEmpty
          ? ''
          : style.dim(' · ${finding.aliases.join(', ')}');
      out
        ..writeln(
          '  ${style.severityLabel(finding.severity)}'
          '${style.bold(finding.ruleId)}$aliases',
        )
        ..writeln('  ${style.dim(finding.title)}');
      final String? fixed = finding.fixedVersion;
      out
        ..writeln(
          fixed == null
              ? '  ${style.yellow('No fix available yet.')}'
              : '  ${style.green('Fix:')} upgrade to ${style.bold(fixed)} '
                    'or later',
        )
        ..writeln('  ${style.dim(finding.url ?? '')}')
        ..writeln();
    }
  }

  /// Writes the clean packages in verbose mode.
  void _writeClean(StringBuffer out, AnsiStyler style) {
    final List<LockfileEntry> clean = scan.scanned
        .where((p) => _findingsOf(p).isEmpty)
        .toList();
    if (!verbose || clean.isEmpty) {
      return;
    }
    out.writeln(style.dim('Clean packages (${clean.length}):'));
    for (final package in clean) {
      out.writeln(style.dim('  ✔ ${package.name} ${package.version}'));
    }
  }

  /// Writes the closing summary.
  void _writeSummary(StringBuffer out, AnsiStyler style, int vulnerable) {
    final String suppressed = suppressedCount == 0
        ? ''
        : style.dim(' ($suppressedCount suppressed by ignore rules)');
    if (findings.isEmpty) {
      out.writeln(
        '${style.green(style.bold('No vulnerabilities found.'))} '
        '${scan.scanned.length} packages scanned.$suppressed',
      );
      return;
    }
    out
      ..writeln(
        style.red(
          style.bold(
            '${findings.length} '
            'vulnerabilit${findings.length == 1 ? 'y' : 'ies'} found across '
            '$vulnerable package${vulnerable == 1 ? '' : 's'}.',
          ),
        ),
      )
      ..writeln('  ${severityBreakdown(findings)}$suppressed')
      ..writeln(
        '${style.dim('Run ')}dart pub upgrade'
        '${style.dim(' to update dependencies, or pin a safe version in '
        'pubspec.yaml.')}',
      );
  }
}
