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
import 'package:inspectra/src/audit/audit_report.dart';
import 'package:inspectra/src/audit/audit_scan.dart';
import 'package:inspectra/src/audit/audit_service.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/inspectra_command.dart';
import 'package:inspectra/src/policy/filter_outcome.dart';
import 'package:inspectra/src/pub/lockfile.dart';
import 'package:inspectra/src/pub/lockfile_entry.dart';
import 'package:inspectra/src/pub/lockfile_parser.dart';
import 'package:inspectra/src/report/command_report.dart';

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
    final String path = session.resolve(results['lockfile'] as String);
    final String display = session.display(path);
    final Lockfile lockfile = const LockfileParser().parseFile(path);
    final AuditService service = session.auditService();
    final List<LockfileEntry> total = lockfile.auditable(
      session.config.network.pubHostedUrl,
    );
    session.console.info(
      'Scanning ${total.length} packages from $display against OSV.dev...',
    );
    final AuditScan scan = await service.audit(
      lockfile,
      displayPath: display,
      onProgress: (done, all) => session.console.detail('  $done/$all'),
    );
    final FilterOutcome outcome = session.filter().apply(scan.findings);
    return AuditReport(
      scan: scan,
      findings: outcome.kept,
      suppressedCount: outcome.suppressed.length,
      baselinedCount: outcome.baselined.length,
      verbose: results['verbose'] == true,
    );
  }
}
