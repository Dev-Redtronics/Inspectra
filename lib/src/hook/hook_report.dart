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
import '../report/command_report.dart';

/// The report of the `hook` command.
final class HookReport implements CommandReport {
  /// Creates a report for the [action] (`install` or `remove`) on the hook
  /// at [path]; [changed] tells whether anything was modified and [message]
  /// describes the result.
  const HookReport({
    required this.action,
    required this.path,
    required this.changed,
    required this.message,
  });

  /// The performed action.
  final String action;

  /// The hook path, or `null` when nothing was found.
  final String? path;

  /// Whether a file was written or removed.
  final bool changed;

  /// The user facing result.
  final String message;

  /// The name of the command.
  @override
  String get command => 'hook';

  /// The hook command never reports findings.
  @override
  List<Finding> get findings => const <Finding>[];

  /// The hook command never fails because of findings.
  ///
  /// Returns `false`.
  @override
  bool isFailing(Severity threshold) => false;

  /// Builds the JSON body.
  ///
  /// Returns the JSON body.
  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'action': action,
    'path': path,
    'changed': changed,
    'message': message,
  };

  /// Writes the human readable report.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    out.writeln(changed ? style.green('✔ $message') : message);
  }
}
