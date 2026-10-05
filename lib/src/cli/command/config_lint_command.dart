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

import 'package:args/args.dart';
import 'package:inspectra/src/cli/command/config_tool_command.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/report/command_report.dart';

/// `inspectra config lint`: reports risky settings of the configuration as
/// findings.
final class ConfigLintCommand extends ConfigToolCommand {
  /// Creates the command.
  ConfigLintCommand(super.context);

  /// The command name.
  @override
  String get name => 'lint';

  /// The one line description.
  @override
  String get description =>
      'Report risky settings: insecure URLs, unpinned or disabled Trivy, '
      'ignore rules without expiry, misspelled INSPECTRA_* variables.';

  /// Checks the configuration of the project.
  ///
  /// Returns the report.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async => lintReport(session, results);
}
