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

import '../../audit/audit_report.dart';
import '../../pub/lockfile_parser.dart';
import '../../report/command_report.dart';
import '../command_session.dart';
import '../inspectra_command.dart';

/// `inspectra audit`: checks every locked package against OSV.dev.
final class AuditCommand extends InspectraCommand {
  /// Creates the command.
  AuditCommand(super.context) {
    argParser.addOption(
      'lockfile',
      abbr: 'l',
      help: 'Path to pubspec.lock.',
      defaultsTo: 'pubspec.lock',
    );
  }

  /// The command name.
  @override
  String get name => 'audit';

  /// The one line description.
  @override
  String get description =>
      'Scan pubspec.lock against the OSV.dev vulnerability database.';

  /// Audits the lockfile.
  ///
  /// Returns the audit report.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    final path = session.resolve(results['lockfile'] as String);
    final display = session.display(path);
    final lockfile = const LockfileParser().parseFile(path);
    final service = session.auditService();
    final total = lockfile.auditable(session.config.network.pubHostedUrl);
    session.console.info(
      'Scanning ${total.length} packages from $display against OSV.dev...',
    );
    final scan = await service.audit(
      lockfile,
      displayPath: display,
      onProgress: (done, all) => session.console.detail('  $done/$all'),
    );
    final outcome = session.filter().apply(scan.findings);
    return AuditReport(
      scan: scan,
      findings: outcome.kept,
      suppressedCount: outcome.suppressed.length,
      verbose: results['verbose'] == true,
    );
  }
}
