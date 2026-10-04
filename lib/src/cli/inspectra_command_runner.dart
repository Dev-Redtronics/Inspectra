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

import '../version.dart';
import 'command/add_command.dart';
import 'command/audit_command.dart';
import 'command/hook_command.dart';
import 'command/inspect_command.dart';
import 'command/scan_command.dart';
import 'command/trivy_command.dart';
import 'command/trust_command.dart';
import 'command/typosquat_command.dart';
import 'command_context.dart';
import 'exit_code.dart';

/// The `inspectra` command line.
///
/// Running `inspectra` without a command, or with options only, runs
/// `scan`. Usage errors exit with `64`; unexpected internal errors are
/// caught, reported and exit with `70` instead of crashing with a stack
/// trace (set `INSPECTRA_DEBUG=1` to print it).
final class InspectraCommandRunner extends CommandRunner<int> {
  /// Creates the command line for [context].
  InspectraCommandRunner(this.context)
    : super(
        'inspectra',
        'Supply-chain security scanner for Dart and Flutter projects.',
      ) {
    argParser.addFlag(
      'version',
      negatable: false,
      help: 'Print the Inspectra version and exit.',
    );
    addCommand(ScanCommand(context));
    addCommand(AuditCommand(context));
    addCommand(InspectCommand(context));
    addCommand(TrustCommand(context));
    addCommand(TyposquatCommand(context));
    addCommand(AddCommand(context));
    addCommand(HookCommand(context));
    addCommand(TrivyCommand(context));
  }

  /// The outside world.
  final CommandContext context;

  /// The arguments that are handled by the runner itself.
  static const Set<String> _runnerFlags = <String>{'-h', '--help', '--version'};

  /// Prints the usage to standard output of the [context].
  @override
  void printUsage() => context.out.writeln(usage);

  /// Parses and runs [args].
  ///
  /// Returns the process exit code.
  @override
  Future<int> run(Iterable<String> args) async {
    final arguments = _withDefaultCommand(args.toList());
    try {
      final results = parse(arguments);
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
  /// Returns the arguments to parse.
  List<String> _withDefaultCommand(List<String> args) {
    if (args.isEmpty) {
      return <String>['scan'];
    }
    final first = args.first;
    final isOption = first.startsWith('-') && !_runnerFlags.contains(first);
    if (isOption) {
      return <String>['scan', ...args];
    }
    return args;
  }
}
