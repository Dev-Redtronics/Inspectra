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

import '../../model/inspectra_exception.dart';
import '../../report/command_report.dart';
import '../command_session.dart';
import '../inspectra_command.dart';

/// `inspectra add <package> [version]`: audits a package and adds exactly
/// the audited version to the current project.
final class AddCommand extends InspectraCommand {
  /// Creates the command.
  AddCommand(super.context) {
    argParser
      ..addFlag(
        'dev',
        abbr: 'd',
        negatable: false,
        help: 'Add under dev_dependencies.',
      )
      ..addFlag(
        'force',
        negatable: false,
        help:
            'Install despite reported security findings. Never overrides '
            'an incomplete verification.',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Audit only; do not modify pubspec.yaml.',
      );
  }

  /// The command name.
  @override
  String get name => 'add';

  /// The one line description.
  @override
  String get description =>
      'Audit a package and add its exact version to pubspec.yaml.';

  /// The positional arguments.
  @override
  String get invocation => 'inspectra add <package> [version] [options]';

  /// Audits and adds the package.
  ///
  /// Returns the add report.
  ///
  /// Throws an [InvalidUsageException] when the package is missing.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    if (results.rest.isEmpty) {
      throw const InvalidUsageException('add requires a <package> argument.');
    }
    final name = results.rest[0];
    session.console.info('Safe package addition: $name');
    return session.packageAdder().add(
      name: name,
      version: results.rest.length > 1 ? results.rest[1] : null,
      dev: results['dev'] == true,
      force: results['force'] == true,
      dryRun: results['dry-run'] == true,
      projectDirectory: session.context.workingDirectory,
      filter: session.filter(),
      onStatus: (message) => session.console.info('  $message'),
    );
  }
}
