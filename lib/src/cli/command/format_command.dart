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

import 'package:inspectra/src/cli/package_check_command.dart';

/// `inspectra format`: checks the formatting, or formats with `--fix`.
final class FormatCommand extends PackageCheckCommand {
  /// Creates the command.
  FormatCommand(super.context) {
    argParser.addFlag(
      'fix',
      negatable: false,
      help: 'Format the files instead of only checking them.',
    );
  }

  /// The command name.
  @override
  String get name => 'format';

  /// The one line description.
  @override
  String get description =>
      'Check that the Dart files are formatted, or format them with --fix.';

  /// Runs the format check.
  ///
  /// Returns whether it passed.
  @override
  Future<bool> runChecks() =>
      runFormat(loadPackageConfig(), fix: argResults?.flag('fix') ?? false);
}
