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
import 'package:inspectra/src/config/inspectra_config.dart';

/// `inspectra check`: runs every enabled package check — format, lint,
/// API, the configured Trivy scans and coverage.
final class CheckCommand extends PackageCheckCommand {
  /// Creates the command.
  CheckCommand(super.context);

  /// The command name.
  @override
  String get name => 'check';

  /// The one line description.
  @override
  String get description =>
      'Run every enabled package check: format, lint, style, API, changelog, '
      'Trivy scans and coverage.';

  /// Runs the enabled checks one after the other.
  ///
  /// Returns whether all of them passed.
  @override
  Future<bool> runChecks() async {
    final InspectraConfig config = loadPackageConfig();
    final steps = <(bool, Future<bool> Function())>[
      (config.format.enabled, () => runFormat(config)),
      (config.lint.enabled, () => runLintGate(config)),
      (config.style.enabled, () => runStyleGate(config)),
      (config.api.enabled, () => runApiCheck(config)),
      (config.changelog.enabled, () => runChangelogCheck(config)),
      (config.trivy.enabled, () => runScans(config)),
      (config.coverage.enabled, () => runCoverageGate(config)),
    ];
    final List<(bool, Future<bool> Function())> enabled = steps
        .where((step) => step.$1)
        .toList();
    if (enabled.isEmpty) {
      out.writeln(
        'Nothing is enabled. Enable "format", "lint", "style", "api", '
        '"changelog", "trivy" or "coverage" in the Inspectra configuration.',
      );
      return true;
    }
    var passed = true;
    for (final (_, check) in enabled) {
      passed = await check() && passed;
    }
    return passed;
  }
}
