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

import '../archive/archive_entry.dart';
import '../archive/archive_limits.dart';
import '../archive/archive_reader.dart';
import '../config/inspect_config.dart';
import '../model/finding.dart';
import '../model/finding_source.dart';
import '../model/inspectra_exception.dart';
import '../model/severity.dart';
import '../model/source_location.dart';
import '../pub/package_archive_downloader.dart';
import '../pub/pub_package.dart';
import '../pub/pub_repository_client.dart';
import '../pub/pubspec.dart';
import '../pub/pubspec_parser.dart';
import '../trust/trust_assessor.dart';
import 'archive_scanner.dart';
import 'entropy_scanner.dart';
import 'inspection_result.dart';
import 'pubspec_scanner.dart';
import 'regex_scanner.dart';
import 'unicode_scanner.dart';

/// Inspects the published source of a package version before it is used.
///
/// The pipeline is:
///
/// 1. fetch the version listing (once, shared with the trust assessment);
/// 2. download the archive and verify host and SHA-256 checksum;
/// 3. read the archive into memory within the configured limits — nothing
///    is ever written to disk;
/// 4. run the regex, entropy, Unicode, archive and pubspec scanners;
/// 5. assess the trust signals of the requested version.
final class PackageInspector {
  /// Creates an inspector.
  const PackageInspector({
    required this.repository,
    required this.downloader,
    required this.trustAssessor,
    required this.config,
  });

  /// The pub repository client.
  final PubRepositoryClient repository;

  /// The archive downloader.
  final PackageArchiveDownloader downloader;

  /// The trust assessor.
  final TrustAssessor trustAssessor;

  /// The inspector configuration.
  final InspectConfig config;

  /// Inspects [version] of package [name].
  ///
  /// [onStatus] receives progress messages. [knownListing] avoids fetching
  /// the version listing again when the caller already has it.
  ///
  /// Returns the inspection outcome.
  ///
  /// Throws an [InvalidUsageException] when the package or version does not
  /// exist, an [UnavailableException] when the repository cannot be queried
  /// or the archive fails verification, and an [InvalidInputException] when
  /// the archive is malformed or exceeds a limit.
  Future<InspectionResult> inspect(
    String name,
    String version, {
    required void Function(String message) onStatus,
    PubPackage? knownListing,
  }) async {
    onStatus('Fetching package metadata...');
    final listing = knownListing ?? await repository.package(name);
    if (listing == null) {
      throw InvalidUsageException(
        'Package "$name" was not found on '
        '${repository.baseUrl}.',
      );
    }
    final record = listing.find(version);
    if (record == null) {
      throw InvalidUsageException(
        'Version $version of "$name" was never '
        'published.',
      );
    }
    onStatus('Downloading and verifying the archive...');
    final bytes = await downloader.download(name, record);
    final reader = ArchiveReader(
      ArchiveLimits(
        maxArchiveBytes: config.maxArchiveBytes,
        maxExtractedBytes: config.maxExtractedBytes,
        maxEntries: config.maxEntries,
      ),
    );
    final entries = reader.readTarGz(bytes);
    final dartFiles = entries.where(
      (e) => e.isFile && e.path.endsWith('.dart'),
    );
    onStatus('Running security scanners on ${entries.length} entries...');
    final findings = <Finding>[
      ...RegexScanner(
        extraTrustedHosts: config.trustedHosts,
        excludedDirectories: config.excludeDirectories,
      ).scan(entries),
      ...EntropyScanner(
        excludedSuffixes: config.entropyExcludes,
        excludedDirectories: config.excludeDirectories,
      ).scan(entries),
      ...const UnicodeScanner().scan(entries),
      ...const ArchiveScanner().scan(entries),
      ..._scanPubspec(entries),
    ];
    onStatus('Assessing trust signals...');
    final trust = await trustAssessor.assess(listing, version);
    return InspectionResult(
      package: name,
      version: version,
      entryCount: entries.length,
      dartFileCount: dartFiles.length,
      findings: <Finding>[...findings, ...trust.findings],
      trust: trust,
    );
  }

  /// Scans the runtime dependencies declared by the package's own
  /// `pubspec.yaml`.
  ///
  /// Returns the findings; a malformed pubspec is itself a finding.
  List<Finding> _scanPubspec(List<ArchiveEntry> entries) {
    final entry = entries
        .where((e) => e.isFile && e.path == 'pubspec.yaml')
        .firstOrNull;
    if (entry == null) {
      return const <Finding>[];
    }
    final Pubspec parsed;
    try {
      parsed = const PubspecParser().parse(entry.text, path: entry.path);
    } on InvalidInputException catch (error) {
      return <Finding>[
        Finding(
          ruleId: 'MALFORMED_PUBSPEC',
          source: FindingSource.pubspec,
          severity: Severity.high,
          title: error.message,
          location: const SourceLocation('pubspec.yaml'),
        ),
      ];
    }
    final runtimeOnly = Pubspec(
      path: parsed.path,
      name: parsed.name,
      dependencies: parsed.dependencies,
      sdkConstraint: parsed.sdkConstraint,
    );
    return const PubspecScanner().scan(
      runtimeOnly,
      content: entry.text,
      displayPath: entry.path,
    );
  }
}
