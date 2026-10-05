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
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/command_report.dart';

/// The report of a successful `config validate`.
///
/// The JSON body has `source`, the configuration file or `null`, `valid`
/// and `files`, the files the configuration refers to that were checked.
final class ConfigValidateReport implements CommandReport {
  /// Creates the report of the configuration read from [source], whose
  /// referenced [files] exist.
  const ConfigValidateReport({required this.source, required this.files});

  /// The configuration file, or `null` without one.
  final String? source;

  /// The files the configuration refers to, all of which exist.
  final List<String> files;

  /// The name of the command.
  @override
  String get command => 'config validate';

  /// Validation reports problems as an input error, not as findings.
  @override
  List<Finding> get findings => const <Finding>[];

  /// A valid configuration never fails.
  ///
  /// Returns `false`.
  @override
  bool isFailing(Severity threshold) => false;

  /// Builds the JSON body.
  ///
  /// Returns the JSON body.
  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'source': source,
    'valid': true,
    'files': files,
  };

  /// Writes the human readable report.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    final String where = source ?? 'the built-in defaults';
    final referenced = files.isEmpty
        ? ''
        : ' ${files.length} referenced file(s) exist.';
    out.writeln(
      style.green(
        '✔ The configuration of $where is valid.'
        '$referenced',
      ),
    );
  }
}
