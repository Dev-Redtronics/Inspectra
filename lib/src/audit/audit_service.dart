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

import '../model/finding.dart';
import '../model/finding_source.dart';
import '../model/source_location.dart';
import '../osv/osv_client.dart';
import '../osv/osv_vulnerability.dart';
import '../pub/lockfile_entry.dart';
import '../pub/lockfile.dart';
import 'audit_scan.dart';

/// Audits the packages of a lockfile against OSV.dev.
final class AuditService {
  /// Creates a service querying [osvClient]; [mirrorUrl] is the configured
  /// pub repository, which is treated as a mirror of pub.dev.
  const AuditService({required this.osvClient, required this.mirrorUrl});

  /// The OSV.dev client.
  final OsvClient osvClient;

  /// The configured pub repository URL.
  final String mirrorUrl;

  /// Audits [lockfile], reporting it as [displayPath].
  ///
  /// [onProgress] receives the number of processed and total packages.
  ///
  /// Returns the raw audit outcome.
  Future<AuditScan> audit(
    Lockfile lockfile, {
    required String displayPath,
    void Function(int done, int total)? onProgress,
  }) async {
    final scanned = lockfile.auditable(mirrorUrl);
    final skipped = <LockfileEntry>[
      ...lockfile.unhosted,
      ...lockfile.privatelyHosted(mirrorUrl),
    ];
    if (scanned.isEmpty) {
      return AuditScan(
        lockfilePath: displayPath,
        scanned: scanned,
        skipped: skipped,
        findings: const <Finding>[],
      );
    }
    final advisories = await osvClient.query(scanned, onProgress: onProgress);
    final findings = <Finding>[
      for (final entry in advisories.entries)
        for (final advisory in entry.value)
          _finding(entry.key, advisory, displayPath),
    ];
    return AuditScan(
      lockfilePath: displayPath,
      scanned: scanned,
      skipped: skipped,
      findings: findings,
    );
  }

  /// Converts one [advisory] affecting [package] into a finding.
  ///
  /// Returns the finding located at the lockfile [displayPath].
  Finding _finding(
    LockfileEntry package,
    OsvVulnerability advisory,
    String displayPath,
  ) {
    final summary = advisory.summary.isEmpty ? advisory.id : advisory.summary;
    return Finding(
      ruleId: advisory.id,
      source: FindingSource.osv,
      severity: advisory.severity,
      title: summary,
      description: advisory.details,
      location: SourceLocation(displayPath),
      packageName: package.name,
      packageVersion: package.version,
      fixedVersion: advisory.fixedVersionFor(package.name, package.version),
      aliases: advisory.aliases,
      url: advisory.detailsUrl,
    );
  }
}
