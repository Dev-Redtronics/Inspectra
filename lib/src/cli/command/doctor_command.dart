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

import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:inspectra/src/cli/command_context.dart';
import 'package:inspectra/src/cli/config_bases.dart';
import 'package:inspectra/src/cli/exit_code.dart';
import 'package:inspectra/src/doctor/doctor.dart';
import 'package:inspectra/src/doctor/doctor_check.dart';
import 'package:inspectra/src/doctor/doctor_status.dart';
import 'package:inspectra/src/util/dart_tool.dart';
import 'package:path/path.dart' as p;

/// `inspectra doctor`: checks what Inspectra needs on this machine and in
/// this project. It works while the configuration is broken, which it
/// reports as one of its checks.
final class DoctorCommand extends Command<int> {
  /// Creates the command with its `--format` and `--offline` options.
  DoctorCommand(this.context) {
    argParser
      ..addOption(
        'format',
        abbr: 'f',
        help: 'Output format.',
        allowed: <String>['text', 'json'],
        defaultsTo: 'text',
      )
      ..addFlag(
        'offline',
        negatable: false,
        help: 'Do not contact OSV.dev, the registry and the Trivy releases.',
      );
  }

  /// The outside world.
  final CommandContext context;

  /// The command name.
  @override
  String get name => 'doctor';

  /// The one line description.
  @override
  String get description =>
      'Check the configuration, the Dart and Flutter SDKs, Git, Trivy, the '
      'network and the cache.';

  /// Prints the usage to standard output of the [context].
  @override
  void printUsage() => context.out.writeln(usage);

  /// Runs the checks and prints them.
  ///
  /// Returns `0`, or `1` when a check failed.
  @override
  Future<int> run() async {
    final directory = globalResults?['directory'] as String?;
    final List<DoctorCheck> checks = await Doctor(
      packageRoot: p.normalize(
        p.join(context.workingDirectory, directory ?? '.'),
      ),
      processRunner: context.processRunner,
      environment: context.environment,
      host: context.host,
      cacheRoot: cacheRootOf(context),
      dartExecutable: dartExecutable(),
      offline: argResults?['offline'] == true,
    ).run();
    final bool healthy = checks.every(
      (check) => check.status != DoctorStatus.fail,
    );
    if (argResults?['format'] == 'json') {
      context.out.writeln(
        const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'command': 'doctor',
          'healthy': healthy,
          'checks': <Map<String, Object?>>[
            for (final check in checks) check.toJson(),
          ],
        }),
      );
      return healthy ? ExitCode.success.code : ExitCode.findings.code;
    }
    for (final check in checks) {
      context.out.writeln(
        '${check.status.mark} ${check.name.padRight(18)} ${check.detail}',
      );
    }
    final int failed = checks
        .where((check) => check.status == DoctorStatus.fail)
        .length;
    context.out.writeln(
      healthy ? 'No problems found.' : '$failed check(s) failed.',
    );
    return healthy ? ExitCode.success.code : ExitCode.findings.code;
  }
}
