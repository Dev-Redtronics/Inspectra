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
import 'package:args/command_runner.dart';
import 'package:inspectra/src/cli/command/add_command.dart';
import 'package:inspectra/src/cli/command/api_command.dart';
import 'package:inspectra/src/cli/command/audit_command.dart';
import 'package:inspectra/src/cli/command/baseline_command.dart';
import 'package:inspectra/src/cli/command/changelog_command.dart';
import 'package:inspectra/src/cli/command/check_command.dart';
import 'package:inspectra/src/cli/command/config_command.dart';
import 'package:inspectra/src/cli/command/coverage_command.dart';
import 'package:inspectra/src/cli/command/deps_command.dart';
import 'package:inspectra/src/cli/command/format_command.dart';
import 'package:inspectra/src/cli/command/hook_command.dart';
import 'package:inspectra/src/cli/command/inspect_command.dart';
import 'package:inspectra/src/cli/command/lint_command.dart';
import 'package:inspectra/src/cli/command/report_command.dart';
import 'package:inspectra/src/cli/command/scan_command.dart';
import 'package:inspectra/src/cli/command/style_command.dart';
import 'package:inspectra/src/cli/command/trivy_command.dart';
import 'package:inspectra/src/cli/command/trust_command.dart';
import 'package:inspectra/src/cli/command/typosquat_command.dart';
import 'package:inspectra/src/cli/command_context.dart';
import 'package:inspectra/src/cli/exit_code.dart';
import 'package:inspectra/src/version.dart';

/// The `inspectra` command line.
///
/// Running `inspectra` without a command, or with options only, runs
/// `scan`. The supply-chain commands are `scan`, `audit`, `inspect`,
/// `trust`, `typosquat`, `deps`, `add`, `hook` and `trivy`; the package
/// checks are `check`, `format`, `lint`, `style`, `api` and `coverage`;
/// `changelog`
/// generates, checks and prints the changelog; `baseline` records the
/// accepted findings so that only new ones fail; `config` shows, validates
/// and lints the configuration. The global `--directory`
/// option selects the package to work on. Usage errors exit with `64`;
/// unexpected internal errors are caught, reported and exit with `70`
/// instead of crashing with a stack trace (set `INSPECTRA_DEBUG=1` to print
/// it).
final class InspectraCommandRunner extends CommandRunner<int> {
  /// Creates the command line for [context].
  InspectraCommandRunner(this.context)
    : super(
        'inspectra',
        'Supply-chain security scanner for Dart and Flutter projects.',
      ) {
    argParser
      ..addFlag(
        'version',
        negatable: false,
        help: 'Print the Inspectra version and exit.',
      )
      ..addOption(
        'directory',
        abbr: 'C',
        help: 'The package or project to work on.',
        valueHelp: 'path',
      );
    addCommand(ScanCommand(context));
    addCommand(AuditCommand(context));
    addCommand(InspectCommand(context));
    addCommand(TrustCommand(context));
    addCommand(TyposquatCommand(context));
    addCommand(DepsCommand(context));
    addCommand(AddCommand(context));
    addCommand(HookCommand(context));
    addCommand(TrivyCommand(context));
    addCommand(CheckCommand(context));
    addCommand(FormatCommand(context));
    addCommand(LintCommand(context));
    addCommand(StyleCommand(context));
    addCommand(ApiCommand(context));
    addCommand(CoverageCommand(context));
    addCommand(ChangelogCommand(context));
    addCommand(BaselineCommand(context));
    addCommand(ConfigCommand(context));
    addCommand(ReportCommand(context));
  }

  /// The outside world.
  final CommandContext context;

  /// The arguments that are handled by the runner itself.
  static const _runnerFlags = <String>{
    '-h',
    '--help',
    '--version',
    '-C',
    '--directory',
  };

  /// Prints the usage to standard output of the [context].
  @override
  void printUsage() => context.out.writeln(usage);

  /// Parses and runs [args].
  ///
  /// Returns the process exit code.
  @override
  Future<int> run(Iterable<String> args) async {
    final List<String> arguments = _withDefaultCommand(args.toList());
    try {
      final ArgResults results = parse(arguments);
      if (results['version'] == true) {
        context.out.writeln('inspectra $inspectraVersion');
        return ExitCode.success.code;
      }
      return await runCommand(results) ?? ExitCode.success.code;
    } on UsageException catch (error) {
      context.err
        ..writeln('error: ${error.message}')
        ..writeln()
        ..writeln(error.usage);
      return ExitCode.usage.code;
    } on Object catch (error, stackTrace) {
      context.err.writeln('error: internal error: $error');
      if (context.environment['INSPECTRA_DEBUG'] != null) {
        context.err.writeln(stackTrace);
      }
      return ExitCode.software.code;
    }
  }

  /// Inserts the default `scan` command when no command is given.
  ///
  /// Global options (`--directory`) may precede it; `--help` and
  /// `--version` are left to the runner.
  ///
  /// Returns the arguments to parse.
  List<String> _withDefaultCommand(List<String> args) {
    var index = 0;
    while (index < args.length) {
      final String argument = args[index];
      if (_runnerFlags.contains(argument) && !_takesValue(argument)) {
        return args;
      }
      if (_takesValue(argument)) {
        index += 2;
        continue;
      }
      if (argument.startsWith('--directory=')) {
        index++;
        continue;
      }
      if (!argument.startsWith('-')) {
        return args;
      }
      return <String>[...args.take(index), 'scan', ...args.skip(index)];
    }
    return <String>[...args, 'scan'];
  }

  /// Whether the global [argument] consumes the next argument as its value.
  ///
  /// Returns `true` for `-C` and `--directory`.
  bool _takesValue(String argument) =>
      argument == '-C' || argument == '--directory';
}
