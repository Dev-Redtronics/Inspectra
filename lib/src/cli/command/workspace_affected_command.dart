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
import 'package:inspectra/src/changelog/git_history.dart';
import 'package:inspectra/src/cli/command_context.dart';
import 'package:inspectra/src/cli/exit_code.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/workspace/affected_packages.dart';
import 'package:inspectra/src/workspace/workspace.dart';
import 'package:inspectra/src/workspace/workspace_member.dart';
import 'package:path/path.dart' as p;

/// `inspectra workspace affected --since <revision>`: lists the packages of
/// a pub workspace that the changes since a Git revision affect, for a CI
/// matrix that builds only those.
final class WorkspaceAffectedCommand extends Command<int> {
  /// Creates the command with its `--since`, `--format` and
  /// `--no-include-dev` options.
  WorkspaceAffectedCommand(this.context) {
    argParser
      ..addOption(
        'since',
        mandatory: true,
        valueHelp: 'revision',
        help: 'The Git revision to compare with, such as origin/main.',
      )
      ..addOption(
        'format',
        abbr: 'f',
        help: 'Output format: one path per line, or JSON.',
        allowed: <String>['text', 'json'],
        defaultsTo: 'text',
      )
      ..addFlag(
        'include-dev',
        defaultsTo: true,
        help:
            'Also count packages that use a changed package as a '
            'dev_dependency.',
      );
  }

  /// The outside world.
  final CommandContext context;

  /// The command name.
  @override
  String get name => 'affected';

  /// The one line description.
  @override
  String get description =>
      'List the packages that the changes since a Git revision affect, '
      'with the packages depending on them.';

  /// Prints the usage to standard output of the [context].
  @override
  void printUsage() => context.out.writeln(usage);

  /// Lists the affected packages.
  ///
  /// Returns `0`; `64` outside a workspace root or for an unknown
  /// revision; `69` when Git fails.
  @override
  Future<int> run() async {
    final directory = globalResults?['directory'] as String?;
    final String root = p.normalize(
      p.join(context.workingDirectory, directory ?? '.'),
    );
    try {
      final Workspace? workspace = Workspace.load(root);
      if (workspace == null) {
        throw const InvalidUsageException(
          'No pub workspace here: the pubspec.yaml has no workspace: list.',
        );
      }
      final String since = argResults?['since'] as String? ?? '';
      final List<String> changed = await GitHistory(
        processRunner: context.processRunner,
        workingDirectory: workspace.root,
      ).changedFiles(since);
      final List<WorkspaceMember> affected = affectedPackages(
        workspace,
        changed,
        includeDev: argResults?['include-dev'] != false,
      );
      _write(since, changed.length, affected);
      return ExitCode.success.code;
    } on InspectraException catch (error) {
      context.err.writeln('error: ${error.message}');
      return ExitCode.of(error).code;
    }
  }

  /// Writes the [affected] packages, found from [files] changed files
  /// since [since].
  void _write(String since, int files, List<WorkspaceMember> affected) {
    if (argResults?['format'] == 'json') {
      context.out.writeln(
        const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'command': 'workspace affected',
          'since': since,
          'changedFiles': files,
          'packages': <Map<String, Object?>>[
            for (final member in affected)
              <String, Object?>{'name': member.name, 'path': member.path},
          ],
        }),
      );
      return;
    }
    for (final member in affected) {
      context.out.writeln(member.path);
    }
  }
}
