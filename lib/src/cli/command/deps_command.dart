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
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/inspectra_command.dart';
import 'package:inspectra/src/deps/deps_report.dart';
import 'package:inspectra/src/deps/deps_result.dart';
import 'package:inspectra/src/deps/deps_service.dart';
import 'package:inspectra/src/policy/filter_outcome.dart';
import 'package:inspectra/src/report/command_report.dart';

/// `inspectra deps`: checks the pubspecs against the pubspec rules and the
/// dependency policy, without network access, and fixes what can be fixed.
final class DepsCommand extends InspectraCommand {
  /// Creates the command with its `--recursive` and `--fix` flags.
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
      'the dependency policy, offline; --fix applies the fixable rules.';

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
    final DepsResult result = service.run(
      session.resolve(results.rest.firstOrNull ?? '.'),
      recursive: results['recursive'] == true,
      fix: fix,
    );
    final FilterOutcome outcome = session.filter().apply(result.findings);
    return DepsReport(
      result: result,
      findings: outcome.kept,
      suppressedCount: outcome.suppressed.length,
      baselinedCount: outcome.baselined.length,
    );
  }
}
