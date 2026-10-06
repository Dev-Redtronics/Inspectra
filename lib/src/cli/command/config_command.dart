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
import 'package:inspectra/src/cli/command/config_diff_command.dart';
import 'package:inspectra/src/cli/command/config_fetch_command.dart';
import 'package:inspectra/src/cli/command/config_init_command.dart';
import 'package:inspectra/src/cli/command/config_lint_command.dart';
import 'package:inspectra/src/cli/command/config_migrate_command.dart';
import 'package:inspectra/src/cli/command/config_schema_command.dart';
import 'package:inspectra/src/cli/command/config_show_command.dart';
import 'package:inspectra/src/cli/command/config_validate_command.dart';
import 'package:inspectra/src/cli/command_context.dart';

/// `inspectra config`: shows, validates, checks, creates, migrates and
/// compares the configuration and prints its JSON Schema.
final class ConfigCommand extends Command<int> {
  /// Creates the command with its `show`, `validate`, `lint`, `schema`,
  /// `fetch`, `init`, `migrate` and `diff` subcommands.
  ConfigCommand(this.context) {
    addSubcommand(ConfigShowCommand(context));
    addSubcommand(ConfigValidateCommand(context));
    addSubcommand(ConfigLintCommand(context));
    addSubcommand(ConfigSchemaCommand(context));
    addSubcommand(ConfigFetchCommand(context));
    addSubcommand(ConfigInitCommand(context));
    addSubcommand(ConfigMigrateCommand(context));
    addSubcommand(ConfigDiffCommand(context));
  }

  /// The outside world.
  final CommandContext context;

  /// The command name.
  @override
  String get name => 'config';

  /// The one line description.
  @override
  String get description =>
      'Show where each configuration value comes from, validate and lint '
      'the configuration, print its JSON Schema, fetch its remote bases, '
      'create, migrate and compare configurations.';

  /// Prints the usage to standard output of the [context].
  @override
  void printUsage() => context.out.writeln(usage);
}
