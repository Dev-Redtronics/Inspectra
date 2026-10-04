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

import '../../model/finding.dart';
import '../../report/command_report.dart';
import '../../trivy/trivy_outcome.dart';
import '../../trivy/trivy_report.dart';
import '../command_session.dart';
import '../inspectra_command.dart';

/// `inspectra trivy [directory]`: runs only Trivy, locating or downloading
/// it as configured.
final class TrivyCommand extends InspectraCommand {
  /// Creates the command.
  TrivyCommand(super.context) : super(withTrivyOptions: true) {
    argParser
      ..addFlag(
        'install',
        negatable: false,
        help: 'Only make Trivy available (for example to warm a CI cache).',
      )
      ..addFlag(
        'where',
        negatable: false,
        help: 'Only print which Trivy executable would be used.',
      );
  }

  /// The command name.
  @override
  String get name => 'trivy';

  /// The one line description.
  @override
  String get description =>
      'Run Trivy (vulnerabilities, secrets, misconfigurations, licenses).';

  /// The positional arguments.
  @override
  String get invocation => 'inspectra trivy [directory] [options]';

  /// Provisions and runs Trivy.
  ///
  /// Returns the Trivy report.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    final directory = session.resolve(results.rest.firstOrNull ?? '.');
    final display = session.display(directory);
    final provisionOnly =
        results['install'] == true || results['where'] == true;
    if (provisionOnly) {
      final provision = await session.trivyProvisioner().provision(
        onStatus: session.console.info,
      );
      return TrivyReport(
        target: display,
        outcome: TrivyOutcome(
          provision: provision,
          findings: const <Finding>[],
        ),
        findings: const <Finding>[],
        provisionOnly: true,
      );
    }
    final outcome = await session.trivyService().scan(
      directory,
      displayPrefix: display,
      onStatus: session.console.info,
    );
    final filtered = session.filter().apply(outcome.findings);
    return TrivyReport(
      target: display,
      outcome: outcome,
      findings: filtered.kept,
    );
  }
}
