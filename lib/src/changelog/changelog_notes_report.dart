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

/// The report of `changelog notes`: the section of one release, as
/// release notes.
final class ChangelogNotesReport implements CommandReport {
  /// Creates the report of the section of [version], released on [date],
  /// whose text is [notes].
  const ChangelogNotesReport({
    required this.version,
    required this.date,
    required this.notes,
  });

  /// The version.
  final String version;

  /// The release date as written in the changelog, if any.
  final String? date;

  /// The Markdown text of the section, without its heading.
  final String notes;

  /// The name of the command.
  @override
  String get command => 'changelog notes';

  /// Printing release notes never reports findings.
  @override
  List<Finding> get findings => const <Finding>[];

  /// Printing release notes never fails because of findings.
  ///
  /// Returns `false`.
  @override
  bool isFailing(Severity threshold) => false;

  /// Builds the JSON body.
  ///
  /// Returns the JSON body.
  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'date': date,
    'notes': notes,
  };

  /// Writes the notes as they are.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    out.writeln(notes);
  }
}
