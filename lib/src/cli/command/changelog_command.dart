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

import 'package:args/command_runner.dart';
import 'package:inspectra/src/cli/command/changelog_check_command.dart';
import 'package:inspectra/src/cli/command/changelog_generate_command.dart';
import 'package:inspectra/src/cli/command/changelog_notes_command.dart';
import 'package:inspectra/src/cli/command_context.dart';

/// `inspectra changelog`: generates, validates and extracts the changelog.
final class ChangelogCommand extends Command<int> {
  /// Creates the command with its subcommands.
  ChangelogCommand(this.context) {
    addSubcommand(ChangelogGenerateCommand(context));
    addSubcommand(ChangelogCheckCommand(context));
    addSubcommand(ChangelogNotesCommand(context));
  }

  /// The outside world.
  final CommandContext context;

  /// The command name.
  @override
  String get name => 'changelog';

  /// The one line description.
  @override
  String get description =>
      'Generate the changelog from Conventional Commits, check it and '
      'print release notes.';

  /// Prints the usage to standard output of the [context].
  @override
  void printUsage() => context.out.writeln(usage);
}
