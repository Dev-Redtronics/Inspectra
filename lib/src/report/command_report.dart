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

import '../io/ansi_styler.dart';
import '../model/finding.dart';
import '../model/severity.dart';

/// The result of one Inspectra command, renderable in every output format.
///
/// Each command contributes its own human readable layout ([writeText]) and
/// its own JSON structure ([toJson]), which keeps the field names that
/// `dart_audit` users rely on. The generic [findings] list drives SARIF,
/// Markdown and the exit code.
abstract interface class CommandReport {
  /// The command that produced the report, for example `audit`.
  String get command;

  /// Every reported finding, after ignore rules and severity filters.
  List<Finding> get findings;

  /// Serialises the command specific JSON body.
  ///
  /// Returns the JSON body; the renderer adds schema and tool metadata.
  Map<String, Object?> toJson();

  /// Writes the human readable report to [out], styled by [style].
  void writeText(StringBuffer out, AnsiStyler style);

  /// Decides whether the report should fail the command for the given
  /// severity [threshold].
  ///
  /// Returns `true` when the command must exit with `1`.
  bool isFailing(Severity threshold);
}
