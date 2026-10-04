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
import 'package:inspectra/src/trust/trust_info.dart';

/// The report of the `trust` command.
final class TrustReport implements CommandReport {
  /// Creates a report for [info] whose policy filtered findings are
  /// [findings], evaluated at [now].
  const TrustReport({
    required this.info,
    required this.findings,
    required this.now,
  });

  /// The trust assessment.
  final TrustInfo info;

  /// The findings after ignore rules and severity filters.
  @override
  final List<Finding> findings;

  /// The evaluation time, used to print ages.
  final DateTime now;

  /// The name of the command.
  @override
  String get command => 'trust';

  /// Fails when any finding reaches [threshold].
  ///
  /// Returns `true` when the command must exit with `1`.
  @override
  bool isFailing(Severity threshold) =>
      findings.any((finding) => finding.severity.isAtLeast(threshold));

  /// Builds the JSON body with the field names of `dart_audit`.
  ///
  /// Returns the JSON body.
  @override
  Map<String, Object?> toJson() {
    final Map<String, Object?> json = info.toJson();
    json['findings'] = <Object?>[
      for (final finding in findings)
        <String, Object?>{
          'rule': finding.ruleId,
          'severity': finding.severity.label,
          'description': finding.title,
        },
    ];
    return json;
  }

  /// Writes the human readable report.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    final String rule = style.dim('─' * 60);
    out
      ..writeln()
      ..writeln(
        '${style.bold('inspectra')}${style.dim(' — Trust Assessment '
        '· ${info.package} ${info.version}')}',
      )
      ..writeln(rule);
    final DateTime? created = info.createdAt;
    if (created != null) {
      out.writeln(
        '  Created:        ${_date(created)} '
        '(${now.difference(created).inDays} days ago)',
      );
    }
    final DateTime? published = info.publishedAt;
    if (published != null) {
      out.writeln(
        '  Published:      ${_date(published)} '
        '(${now.difference(published).inHours}h ago)',
      );
    }
    out
      ..writeln('  Latest version: ${info.latestVersion}')
      ..writeln('  Likes:          ${info.likeCount ?? 'n/a'}')
      ..writeln('  Downloads (30d): ${info.downloadCount30Days ?? 'n/a'}')
      ..writeln(
        '  Pub points:     '
        '${info.grantedPoints ?? '?'}/${info.maxPoints ?? '?'}',
      )
      ..writeln('  Publisher:      ${_publisher(style)}')
      ..writeln();
    if (findings.isEmpty) {
      out.writeln(style.green('✔ No trust concerns detected.'));
    }
    for (final Finding finding in findings) {
      out.writeln(
        '  ${style.severityLabel(finding.severity)}'
        '${finding.ruleId}: ${finding.title}',
      );
    }
    final bool trusted = !findings.any((f) => f.severity == Severity.critical);
    out
      ..writeln(rule)
      ..writeln(
        trusted
            ? 'Verdict: ${style.green('TRUSTED')}'
            : 'Verdict: ${style.red('NOT TRUSTED')}',
      );
  }

  /// Describes the publisher of the assessed package.
  ///
  /// Returns `<publisher> (verified)` or a red `none (unverified)`.
  String _publisher(AnsiStyler style) {
    final String? publisher = info.publisher;
    if (publisher == null) {
      return style.red('none (unverified)');
    }
    return '$publisher (verified)';
  }

  /// Formats [time] as `YYYY-MM-DD`.
  ///
  /// Returns the date.
  String _date(DateTime time) => time.toIso8601String().substring(0, 10);
}
