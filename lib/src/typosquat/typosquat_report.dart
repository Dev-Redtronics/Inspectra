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

/// The report of the `typosquat` command.
///
/// The JSON body has the stable fields `packages`,
/// `typosquatFindings` and `confusionFindings`.
final class TyposquatReport implements CommandReport {
  /// Creates a report for the analysed [packages] of [pubspecPath] with the
  /// policy filtered [findings]; [confusionChecked] tells whether the
  /// network based confusion check ran.
  const TyposquatReport({
    required this.pubspecPath,
    required this.packages,
    required this.findings,
    required this.confusionChecked,
  });

  /// The display path of the analysed pubspec.
  final String pubspecPath;

  /// The analysed dependency names.
  final List<String> packages;

  /// The findings after ignore rules and severity filters.
  @override
  final List<Finding> findings;

  /// Whether the dependency confusion check ran; it is skipped offline.
  final bool confusionChecked;

  /// The name of the command.
  @override
  String get command => 'typosquat';

  /// Returns the findings of [source].
  List<Finding> _of(FindingSource source) =>
      findings.where((finding) => finding.source == source).toList();

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
    'pubspec': pubspecPath,
    'packages': packages,
    'confusionChecked': confusionChecked,
    'typosquatFindings': <Object?>[
      for (final finding in _of(FindingSource.typosquat))
        <String, Object?>{
          'rule': finding.ruleId,
          'severity': finding.severity.label,
          'description': finding.title,
          'localPackage': finding.packageName,
          'matchedPublicPackage': finding.attributes['matchedPublicPackage'],
        },
    ],
    'confusionFindings': <Object?>[
      for (final finding in _of(FindingSource.confusion))
        <String, Object?>{
          'rule': finding.ruleId,
          'severity': finding.severity.label,
          'description': finding.title,
          'packageName': finding.packageName,
          'publicVersion': finding.attributes['publicVersion'],
        },
    ],
  };

  /// Writes the human readable report.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    final String rule = style.dim('─' * 60);
    out
      ..writeln()
      ..writeln(
        '${style.bold('inspectra')}${style.dim(' — Typosquat & '
        'Confusion Analysis · $pubspecPath · ${packages.length} '
        'dependencies')}',
      )
      ..writeln(rule);
    if (findings.isEmpty) {
      out.writeln(
        style.green('✔ No typosquatting or confusion indicators found.'),
      );
    }
    _section(out, style, 'Typosquatting', _of(FindingSource.typosquat));
    _section(out, style, 'Dependency Confusion', _of(FindingSource.confusion));
    if (!confusionChecked) {
      out.writeln(
        style.yellow('⚠ Dependency confusion check skipped (offline mode).'),
      );
    }
    out
      ..writeln(rule)
      ..writeln('Typosquat / confusion findings: ${findings.length}');
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
    out.writeln('  ${style.bold('$title:')}');
    for (final finding in sectionFindings) {
      out
        ..writeln(
          '  ${style.severityLabel(finding.severity)}'
          '${finding.packageName}  ${style.dim('(${finding.ruleId})')}',
        )
        ..writeln('    ${finding.title}');
    }
    out.writeln();
  }
}
