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
import 'package:inspectra/src/inspect/inspection_report.dart';
import 'package:inspectra/src/inspect/inspection_result.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/policy/filter_outcome.dart';
import 'package:inspectra/src/pub/package_name.dart';
import 'package:inspectra/src/report/command_report.dart';

/// `inspectra inspect <package> <version>`: statically analyses the
/// published source of a package version before it is added.
final class InspectCommand extends InspectraCommand {
  /// Creates the command.
  InspectCommand(super.context);

  /// The command name.
  @override
  String get name => 'inspect';

  /// The one line description.
  @override
  String get description =>
      'Statically analyse a pub.dev package before adding it.';

  /// The positional arguments.
  @override
  String get invocation => 'inspectra inspect <package> <version> [options]';

  /// Inspects the package.
  ///
  /// Returns the inspection report.
  ///
  /// Throws an [InvalidUsageException] when arguments are missing.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    if (results.rest.length < 2) {
      throw const InvalidUsageException(
        'inspect requires <package> and <version> arguments.',
      );
    }
    final String name = PackageName.validate(results.rest[0]);
    final String version = PackageName.validateExactVersion(results.rest[1]);
    session.console.info('Inspecting $name $version...');
    final InspectionResult result = await session.inspector().inspect(
      name,
      version,
      onStatus: (message) => session.console.info('  $message'),
    );
    final FilterOutcome outcome = session
        .filter(baseline: false)
        .apply(result.findings);
    return InspectionReport(
      result: result,
      findings: outcome.kept,
      failScore: session.config.inspect.failScore,
      suppressedCount: outcome.suppressed.length,
    );
  }
}
