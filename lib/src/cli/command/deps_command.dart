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
import 'package:inspectra/src/changelog/git_history.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/inspectra_command.dart';
import 'package:inspectra/src/deps/deps_report.dart';
import 'package:inspectra/src/deps/deps_result.dart';
import 'package:inspectra/src/deps/deps_service.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/policy/filter_outcome.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/workspace/affected_packages.dart';
import 'package:inspectra/src/workspace/workspace.dart';
import 'package:inspectra/src/workspace/workspace_check.dart';
import 'package:inspectra/src/workspace/workspace_member.dart';

/// `inspectra deps`: checks the pubspecs against the pubspec rules and the
/// dependency policy, without network access unless `--online` asks for
/// the rules that need the registry, and fixes what can be fixed.
final class DepsCommand extends InspectraCommand {
  /// Creates the command with its `--recursive`, `--changed-since`,
  /// `--online` and `--fix` options.
  DepsCommand(super.context) {
    argParser
      ..addFlag(
        'recursive',
        abbr: 'r',
        negatable: false,
        help:
            'Also check nested packages, such as the members of a pub '
            'workspace.',
      )
      ..addOption(
        'changed-since',
        valueHelp: 'revision',
        help:
            'With -r on a pub workspace, check only the packages changed '
            'since the Git revision and the packages depending on them.',
      )
      ..addFlag(
        'online',
        negatable: false,
        help:
            'Also check max_major_behind and max_libyear against the '
            'package registry.',
      )
      ..addFlag(
        'fix',
        negatable: false,
        help:
            'Bound constraints, move development packages and add '
            'publish_to: none as dependency_policy requires, keeping '
            'comments and formatting.',
      );
  }

  /// The command name.
  @override
  String get name => 'deps';

  /// The one line description.
  @override
  String get description =>
      'Check the dependencies of pubspec.yaml against the pubspec rules and '
      'the dependency policy, offline unless --online; --fix applies the '
      'fixable rules.';

  /// The positional arguments.
  @override
  String get invocation => 'inspectra deps [directory] [options]';

  /// Checks, and with `--fix` fixes, the pubspecs.
  ///
  /// Returns the report.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    final fix = results['fix'] == true;
    final service = DepsService(
      workingDirectory: session.workingDirectory,
      policy: session.dependencyPolicy(),
      fixer: session.dependencyFixer(),
    );
    if (fix && service.fixer == null) {
      session.console.warning(
        'Nothing to fix: dependency_policy.enabled is not set.',
      );
    }
    final String root = session.resolve(results.rest.firstOrNull ?? '.');
    final online = results['online'] == true;
    if (online && session.config.network.offline) {
      session.console.warning(
        '--online has no effect while network access is off.',
      );
    }
    final recursive = results['recursive'] == true;
    final changedSince = results['changed-since'] as String?;
    final Set<String>? affected = changedSince == null
        ? null
        : await _affected(session, root, changedSince);
    final DepsResult checked = await service.runOnline(
      root,
      recursive: recursive,
      fix: fix,
      trackedFiles: await session.lockfileTracking(root),
      outdated: online ? session.outdatedPolicy() : null,
      include: affected?.contains,
    );
    final DepsResult result = recursive
        ? checked.withFindings(
            checkWorkspace(
              session.config.workspacePolicy,
              root,
              workingDirectory: session.workingDirectory,
            ),
          )
        : checked;
    final FilterOutcome outcome = session.filter().apply(result.findings);
    return DepsReport(
      result: result,
      findings: outcome.kept,
      suppressedCount: outcome.suppressed.length,
      baselinedCount: outcome.baselined.length,
    );
  }

  /// Finds the pubspecs of the workspace in [root] that the changes since
  /// [revision] affect.
  ///
  /// Returns their absolute paths.
  ///
  /// Throws an [InvalidUsageException] when [root] is no workspace root or
  /// Git cannot resolve the revision, and an `UnavailableException` when
  /// Git fails.
  Future<Set<String>> _affected(
    CommandSession session,
    String root,
    String revision,
  ) async {
    final Workspace? workspace = Workspace.load(root);
    if (workspace == null) {
      throw const InvalidUsageException(
        '--changed-since needs the root of a pub workspace; its '
        'pubspec.yaml has no workspace: list.',
      );
    }
    final List<String> changed = await GitHistory(
      processRunner: session.context.processRunner,
      workingDirectory: root,
    ).changedFiles(revision);
    return <String>{
      for (final WorkspaceMember member in affectedPackages(workspace, changed))
        member.pubspecPath,
    };
  }
}
