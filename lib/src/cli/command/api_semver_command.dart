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
import 'package:inspectra/src/api/semver_check.dart';
import 'package:inspectra/src/api/semver_report.dart';
import 'package:inspectra/src/api/semver_result.dart';
import 'package:inspectra/src/changelog/git_history.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/inspectra_command.dart';
import 'package:inspectra/src/report/command_report.dart';

/// `inspectra api semver`: compares the public API with the dump committed
/// at the last release and checks that the version in `pubspec.yaml`
/// makes a large enough step.
final class ApiSemverCommand extends InspectraCommand {
  /// Creates the command with its `--from` option.
  ApiSemverCommand(super.context) {
    argParser.addOption(
      'from',
      help:
          'Compare with this tag or revision instead of the last release '
          'tag.',
      valueHelp: 'revision',
    );
  }

  /// The command name.
  @override
  String get name => 'semver';

  /// The one line description.
  @override
  String get description =>
      'Classify the API changes since the last release as breaking or '
      'additive and check the version in pubspec.yaml.';

  /// Compares the API and checks the version.
  ///
  /// Returns the report.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    final history = GitHistory(
      processRunner: session.context.processRunner,
      workingDirectory: session.workingDirectory,
    );
    if (await history.isShallow()) {
      session.console.warning(
        'The repository is a shallow clone, so release tags may be missing. '
        'Fetch the whole history, for example with "fetch-depth: 0" in '
        'actions/checkout.',
      );
    }
    final SemverResult result = await checkSemver(
      session.config,
      session.workingDirectory,
      history,
      from: results['from'] as String?,
    );
    return SemverReport(result);
  }
}
