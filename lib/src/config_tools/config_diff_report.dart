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

import 'dart:convert';

import 'package:inspectra/src/config_tools/config_change.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/command_report.dart';

/// The report of `config diff`: the options whose values differ between
/// two configurations.
///
/// The JSON body has `from` and `to`, the labels of the configurations,
/// and `changes`, one object per option with `key`, `from`, `to` and
/// `weaker`.
final class ConfigDiffReport implements CommandReport {
  /// Creates the report of the [changes] from the configuration [from] to
  /// [to]; with [failOnWeaker], a weaker value fails the command.
  const ConfigDiffReport({
    required this.from,
    required this.to,
    required this.changes,
    this.failOnWeaker = false,
  });

  /// The label of the first configuration.
  final String from;

  /// The label of the second configuration.
  final String to;

  /// The options whose values differ.
  final List<ConfigChange> changes;

  /// Whether a weaker value fails the command.
  final bool failOnWeaker;

  /// The name of the command.
  @override
  String get command => 'config diff';

  /// A comparison has no findings.
  @override
  List<Finding> get findings => const <Finding>[];

  /// Returns whether [failOnWeaker] is set and an option became weaker,
  /// whatever the [threshold].
  @override
  bool isFailing(Severity threshold) =>
      failOnWeaker && changes.any((change) => change.weaker);

  /// Builds the JSON body.
  ///
  /// Returns the JSON body.
  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'from': from,
    'to': to,
    'changes': <Map<String, Object?>>[
      for (final change in changes) change.toJson(),
    ],
  };

  /// Writes one line per changed option.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    if (changes.isEmpty) {
      out.writeln(style.green('✔ $from and $to are the same.'));
      return;
    }
    out.writeln('$from → $to:');
    for (final ConfigChange change in changes) {
      final line =
          '  ${change.key}: ${_show(change.from)} → ${_show(change.to)}';
      out.writeln(change.weaker ? style.red('$line (weaker)') : line);
    }
    final int weaker = changes.where((change) => change.weaker).length;
    out.writeln(
      '${changes.length} option(s) differ'
      '${weaker == 0 ? '' : ', $weaker weaker'}.',
    );
  }

  /// Returns [value] for a line of text: unset values as such.
  static String _show(Object? value) =>
      value == null ? 'unset' : jsonEncode(value);
}
