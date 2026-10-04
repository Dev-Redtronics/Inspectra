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

/// `inspectra coverage`: runs the tests with coverage, writes `lcov.info`
/// and checks the threshold.
final class CoverageCommand extends PackageCheckCommand {
  /// Creates the command.
  CoverageCommand(super.context) {
    argParser.addOption(
      'min',
      help: 'Overrides coverage.min_line_coverage, in percent.',
      valueHelp: 'percent',
    );
  }

  /// The command name.
  @override
  String get name => 'coverage';

  /// The one line description.
  @override
  String get description =>
      'Run the tests with coverage, write lcov.info and check the threshold.';

  /// Runs the coverage gate.
  ///
  /// Returns whether it passed.
  ///
  /// Throws a `UsageException` when `--min` is not a percentage.
  @override
  Future<bool> runChecks() {
    final String? min = argResults?.option('min');
    final double? threshold = min == null ? null : double.tryParse(min);
    final bool invalid =
        min != null && (threshold == null || threshold < 0 || threshold > 100);
    if (invalid) {
      usageException('--min must be a number between 0 and 100.');
    }
    return runCoverageGate(loadPackageConfig(), minLineCoverage: threshold);
  }
}
