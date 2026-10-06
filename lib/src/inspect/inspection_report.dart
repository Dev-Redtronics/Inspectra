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

import 'package:inspectra/src/inspect/inspection_result.dart';
import 'package:inspectra/src/inspect/risk_scorer.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/trust/trust_info.dart';

/// The report of the `inspect` command.
///
/// The JSON body has the stable fields (`riskScore`, `riskLabel`,
/// `regexFindings`, `entropyFindings`, `unicodeFindings`, `archiveFindings`,
/// `trustInfo`) and adds `pubspecFindings`, `failScore` and `suppressed`.
final class InspectionReport implements CommandReport {
  /// Creates a report for [result] with the policy filtered [findings].
  ///
  /// [failScore] is the risk score at which the command fails and
  /// [suppressedCount] the number of findings removed by ignore rules.
  InspectionReport({
    required this.result,
    required this.findings,
    required this.failScore,
    required this.suppressedCount,
  }) : riskScore = const RiskScorer().score(findings);

  /// The raw inspection outcome.
  final InspectionResult result;

  /// The findings after ignore rules and severity filters.
  @override
  final List<Finding> findings;

  /// The score from which the package counts as suspicious.
  final int failScore;

  /// The number of suppressed findings.
  final int suppressedCount;

  /// The risk score of the reported findings.
  final int riskScore;

  /// The name of the command.
  @override
  String get command => 'inspect';

  /// The label of [riskScore].
  String get riskLabel => const RiskScorer().label(riskScore);

  /// Whether the package is suspicious, which is decided by the risk score
  /// rather than by the severity [threshold].
  ///
  /// Returns `true` when the risk score reaches [failScore].
  @override
  bool isFailing(Severity threshold) => riskScore >= failScore;

  /// Returns the reported findings of [source].
  List<Finding> _of(FindingSource source) =>
      findings.where((finding) => finding.source == source).toList();

  /// Builds the JSON body.
  ///
  /// Returns the JSON body.
  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'package': result.package,
    'version': result.version,
    'dartFileCount': result.dartFileCount,
    'riskScore': riskScore,
    'riskLabel': riskLabel,
    'failScore': failScore,
    'suppressed': suppressedCount,
    'regexFindings': _of(FindingSource.regex).map(_located).toList(),
    'entropyFindings': _of(FindingSource.entropy)
        .map(
          (f) => <String, Object?>{
            'file': f.location?.path,
            'line': f.location?.line,
            'entropy': f.attributes['entropy'],
            'severity': f.severity.label,
            'snippet': f.snippet,
          },
        )
        .toList(),
    'unicodeFindings': _of(FindingSource.unicode)
        .map(
          (f) => <String, Object?>{
            ..._located(f),
            'codepoint': f.attributes['codepoint'],
          },
        )
        .toList(),
    'archiveFindings': _of(FindingSource.archive)
        .map(
          (f) => <String, Object?>{
            'rule': f.ruleId,
            'severity': f.severity.label,
            'description': f.title,
            'entryName': f.attributes['entryName'],
          },
        )
        .toList(),
    'pubspecFindings': _of(FindingSource.pubspec).map(_located).toList(),
    'trustInfo': result.trust.toJson(),
    'findings': findings.map((finding) => finding.toJson()).toList(),
  };

  /// Serialises a located finding in the layout of the finding lists.
  ///
  /// Returns the JSON object.
  Map<String, Object?> _located(Finding finding) => <String, Object?>{
    'file': finding.location?.path,
    'line': finding.location?.line,
    'rule': finding.ruleId,
    'severity': finding.severity.label,
    'description': finding.title,
    'snippet': finding.snippet,
  };

  /// Writes the human readable report.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    final String rule = style.dim('─' * 60);
    out
      ..writeln()
      ..writeln(
        '${style.bold('inspectra')}${style.dim(' — Source Inspection '
        '· ${result.package} ${result.version} · ${result.dartFileCount} '
        'Dart file(s), ${result.entryCount} entries')}',
      )
      ..writeln(rule);
    _writeTrust(out, style);
    final sections = <(String, FindingSource)>[
      ('Unicode Security Findings', FindingSource.unicode),
      ('Archive Findings', FindingSource.archive),
      ('Regex Findings', FindingSource.regex),
      ('Entropy Findings', FindingSource.entropy),
      ('Pubspec Findings', FindingSource.pubspec),
    ];
    for (final (title, source) in sections) {
      _writeSection(out, style, title, _of(source));
    }
    final Iterable<Finding> codeFindings = findings.where(
      (f) => f.source != FindingSource.trust,
    );
    if (codeFindings.isEmpty) {
      out
        ..writeln(style.green('  ✔ No suspicious patterns found.'))
        ..writeln(style.green('  ✔ No high-entropy strings detected.'))
        ..writeln(style.green('  ✔ No invisible Unicode characters.'))
        ..writeln(style.green('  ✔ No malicious archive structures.'));
    }
    out.writeln(rule);
    _writeScore(out, style);
  }

  /// Writes the trust block.
  void _writeTrust(StringBuffer out, AnsiStyler style) {
    final TrustInfo trust = result.trust;
    out
      ..writeln('  ${style.bold('Package Trust Assessment')}')
      ..writeln('  Publisher: ${_publisher(style)}')
      ..writeln(
        '  Likes: ${trust.likeCount ?? 'n/a'} · Downloads (30d): '
        '${trust.downloadCount30Days ?? 'n/a'}',
      );
    for (final Finding finding in _of(FindingSource.trust)) {
      out.writeln(
        '  ${style.severityLabel(finding.severity)}'
        '${finding.title}',
      );
    }
    out.writeln();
  }

  /// Describes the publisher of the inspected package.
  ///
  /// Returns `<publisher> (verified)` or a red `none`.
  String _publisher(AnsiStyler style) {
    final String? publisher = result.trust.publisher;
    if (publisher == null) {
      return style.red('none');
    }
    return '$publisher (verified)';
  }

  /// Writes one section of located findings.
  void _writeSection(
    StringBuffer out,
    AnsiStyler style,
    String title,
    List<Finding> sectionFindings,
  ) {
    if (sectionFindings.isEmpty) {
      return;
    }
    out.writeln('  ${style.bold('$title (${sectionFindings.length}):')}');
    for (final finding in sectionFindings) {
      out
        ..writeln(
          '  ${style.severityLabel(finding.severity)}'
          '${finding.location ?? ''}',
        )
        ..writeln('    Rule: ${finding.ruleId}')
        ..writeln('    ${finding.title}');
      final String detail = finding.description;
      if (detail.isNotEmpty) {
        out.writeln('    ${style.dim(detail)}');
      }
      final String? snippet = finding.snippet;
      if (snippet != null) {
        out.writeln('    ${style.dim('› $snippet')}');
      }
    }
    out.writeln();
  }

  /// Writes the risk score line.
  void _writeScore(StringBuffer out, AnsiStyler style) {
    final line = 'Risk Score: $riskScore/100 — $riskLabel';
    if (riskScore == 0) {
      out.writeln(style.green(line));
    }
    if (riskScore > 0 && riskScore < failScore) {
      out.writeln(style.yellow(line));
    }
    if (riskScore >= failScore) {
      out.writeln(style.red('$line — Do NOT install without review'));
    }
    if (findings.isNotEmpty) {
      out.writeln('Total findings: ${findings.length}');
    }
  }
}
