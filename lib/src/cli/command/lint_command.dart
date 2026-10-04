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

import 'package:inspectra/src/cli/package_check_command.dart';

/// `inspectra lint`: analyzes the package with its analysis options.
final class LintCommand extends PackageCheckCommand {
  /// Creates the command.
  LintCommand(super.context) {
    argParser.addFlag(
      'fix',
      negatable: false,
      help: 'Apply "dart fix --apply" before analyzing.',
    );
  }

  /// The command name.
  @override
  String get name => 'lint';

  /// The one line description.
  @override
  String get description =>
      'Analyze the package with the rules of analysis_options.yaml.';

  /// Runs the lint check.
  ///
  /// Returns whether it passed.
  @override
  Future<bool> runChecks() =>
      runLintGate(loadPackageConfig(), fix: argResults?.flag('fix') ?? false);
}
