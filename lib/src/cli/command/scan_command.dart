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
import 'package:inspectra/src/policy/filter_outcome.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/scan/scan_report.dart';
import 'package:inspectra/src/scan/scan_result.dart';
import 'package:inspectra/src/scan/scan_service.dart';

/// `inspectra scan [directory]`, the default command: the complete project
/// scan with OSV.dev, the supply chain checks and Trivy.
final class ScanCommand extends InspectraCommand {
  /// Creates the command.
  ScanCommand(super.context) : super(withTrivyOptions: true) {
    argParser.addFlag(
      'recursive',
      abbr: 'r',
      negatable: false,
      help: 'Also scan nested packages (monorepos and pub workspaces).',
    );
  }

  /// The command name.
  @override
  String get name => 'scan';

  /// The one line description.
  @override
  String get description =>
      'Run every project check: OSV.dev audit, supply chain checks and Trivy '
      '(default).';

  /// The positional arguments.
  @override
  String get invocation => 'inspectra [scan] [directory] [options]';

  /// Scans the project.
  ///
  /// Returns the scan report.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    final String root = session.resolve(results.rest.firstOrNull ?? '.');
    final service = ScanService(
      auditService: session.auditService(),
      typosquatDetector: session.typosquatDetector(),
      confusionDetector: session.confusionDetector(),
      trivyService: session.trivyService(),
      workingDirectory: session.workingDirectory,
    );
    final ScanResult result = await service.scan(
      root,
      recursive: results['recursive'] == true,
      onStatus: session.console.info,
    );
    if (!result.confusionChecked) {
      session.console.warning(
        'Dependency confusion check skipped in offline '
        'mode.',
      );
    }
    final FilterOutcome outcome = session.filter().apply(result.findings);
    return ScanReport(
      result: result,
      findings: outcome.kept,
      suppressedCount: outcome.suppressed.length,
      baselinedCount: outcome.baselined.length,
    );
  }
}
