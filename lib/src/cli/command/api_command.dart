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

import 'package:args/command_runner.dart';
import 'package:inspectra/src/cli/command/api_check_command.dart';
import 'package:inspectra/src/cli/command/api_dump_command.dart';
import 'package:inspectra/src/cli/command_context.dart';

/// `inspectra api`: records or checks the public API dump.
final class ApiCommand extends Command<int> {
  /// Creates the command with its `dump` and `check` subcommands.
  ApiCommand(this.context) {
    addSubcommand(ApiDumpCommand(context));
    addSubcommand(ApiCheckCommand(context));
  }

  /// The outside world.
  final CommandContext context;

  /// The command name.
  @override
  String get name => 'api';

  /// The one line description.
  @override
  String get description => 'Record or check the public API dump.';

  /// Prints the usage to standard output of the [context].
  @override
  void printUsage() => context.out.writeln(usage);
}
