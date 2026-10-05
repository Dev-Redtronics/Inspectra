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
import 'package:inspectra/src/config/config_recorder.dart';
import 'package:inspectra/src/config_tools/config_show_report.dart';
import 'package:inspectra/src/report/command_report.dart';

/// `inspectra config show`: prints the effective configuration, optionally
/// with the origin of every value.
final class ConfigShowCommand extends ConfigToolCommand {
  /// Creates the command with its `--explain` and `--only-changed` flags.
  ConfigShowCommand(super.context) {
    argParser
      ..addFlag(
        'explain',
        negatable: false,
        help:
            'Comment every value with its origin: default, the file and '
            'line, an environment variable or the command line.',
      )
      ..addFlag(
        'only-changed',
        negatable: false,
        help: 'Show only the values that differ from the defaults.',
      );
  }

  /// The command name.
  @override
  String get name => 'show';

  /// The one line description.
  @override
  String get description =>
      'Print the effective configuration and where each value comes from.';

  /// Reads the configuration with the origin of every value.
  ///
  /// Returns the report.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    final recorder = ConfigRecorder();
    recordConfig(results, recorder);
    return ConfigShowReport(
      entries: recorder.entries,
      source: recorder.source,
      explain: results['explain'] == true,
      onlyChanged: results['only-changed'] == true,
    );
  }
}
