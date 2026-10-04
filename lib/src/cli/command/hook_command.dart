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

import 'package:args/args.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/inspectra_command.dart';
import 'package:inspectra/src/hook/git_hook_manager.dart';
import 'package:inspectra/src/hook/hook_report.dart';
import 'package:inspectra/src/report/command_report.dart';

/// `inspectra hook [install|remove]`: installs or removes the Git
/// pre-commit hook that audits staged dependency changes.
final class HookCommand extends InspectraCommand {
  /// Creates the command.
  HookCommand(super.context) {
    argParser.addFlag(
      'remove',
      negatable: false,
      help: 'Remove the hook installed by Inspectra.',
    );
  }

  /// The command name.
  @override
  String get name => 'hook';

  /// The one line description.
  @override
  String get description => 'Install or remove the Git pre-commit hook.';

  /// The positional arguments.
  @override
  String get invocation => 'inspectra hook [install|remove] [options]';

  /// Installs or removes the hook.
  ///
  /// Returns the hook report.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    final manager = GitHookManager(
      processRunner: session.context.processRunner,
      workingDirectory: session.workingDirectory,
      host: session.context.host,
    );
    final bool remove =
        results['remove'] == true || results.rest.firstOrNull == 'remove';
    if (remove) {
      final String? removed = await manager.remove();
      return HookReport(
        action: 'remove',
        path: removed,
        changed: removed != null,
        message: removed == null
            ? 'No Inspectra pre-commit hook was found to remove.'
            : 'Pre-commit hook removed from $removed.',
      );
    }
    final (String path, bool existed) = await manager.install();
    return HookReport(
      action: 'install',
      path: path,
      changed: true,
      message: existed
          ? 'Pre-commit hook at $path updated.'
          : 'Pre-commit hook installed at $path. Staged pubspec.yaml and '
                'pubspec.lock changes are now checked on every commit.',
    );
  }
}
