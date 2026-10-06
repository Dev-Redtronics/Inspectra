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

import 'package:inspectra/src/config/trust_thresholds.dart';
import 'package:inspectra/src/io/clock.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/pub/pub_package.dart';
import 'package:inspectra/src/pub/pub_package_options.dart';
import 'package:inspectra/src/pub/pub_repository_client.dart';
import 'package:inspectra/src/pub/pub_score.dart';
import 'package:inspectra/src/pub/pub_version.dart';
import 'package:inspectra/src/trust/trust_info.dart';

/// Assesses how much a published package version can be trusted.
///
/// Rules (thresholds configurable in the `trust:` section):
///
/// * `FRESH_PACKAGE` (CRITICAL) / `YOUNG_PACKAGE` (MEDIUM): the package is
///   very new, the main vector of supply chain attacks;
/// * `FRESH_RELEASE` (CRITICAL): the assessed version was published only
///   hours ago; malicious versions are usually caught within 24–48 hours;
/// * `RETRACTED_VERSION` (HIGH): the publisher retracted the version;
/// * `DISCONTINUED` (HIGH): the package is no longer maintained;
/// * `UNVERIFIED_PUBLISHER` (HIGH): no verified publisher;
/// * `LOW_LIKES`, `LOW_DOWNLOADS`, `LOW_QUALITY_SCORE` (MEDIUM): weak
///   community signals.
///
/// The age is derived from the version history and the publisher from the
/// dedicated endpoint, both of which pub.dev provides, and the requested
/// version rather than the latest is assessed.
final class TrustAssessor {
  /// Creates an assessor.
  const TrustAssessor({
    required this.repository,
    required this.thresholds,
    required this.clock,
  });

  /// The pub repository client.
  final PubRepositoryClient repository;

  /// The configured thresholds.
  final TrustThresholds thresholds;

  /// The clock deciding package and release age.
  final Clock clock;

  /// Assesses [version] of [name], or the latest version when [version] is
  /// `null`.
  ///
  /// Returns the assessment, or `null` when the package does not exist.
  ///
  /// Throws an [InvalidUsageException] when the version was never published
  /// and an [UnavailableException] when the repository cannot be queried.
  Future<TrustInfo?> assessByName(String name, {String? version}) async {
    final PubPackage? listing = await repository.package(name);
    if (listing == null) {
      return null;
    }
    return assess(listing, version ?? listing.latestVersion);
  }

  /// Assesses [version] of the already fetched [listing].
  ///
  /// Returns the assessment.
  ///
  /// Throws an [InvalidUsageException] when the version was never published
  /// and an [UnavailableException] when the repository cannot be queried.
  Future<TrustInfo> assess(PubPackage listing, String version) async {
    final PubVersion? record = listing.find(version);
    if (record == null) {
      throw InvalidUsageException(
        'Version $version of "${listing.name}" was never published.',
      );
    }
    final String name = listing.name;
    final PubScore? score = await repository.score(name);
    final String? publisher = await repository.publisher(name);
    final PubPackageOptions options = await repository.options(name);
    final DateTime now = clock.now();
    final DateTime? createdAt = listing.firstPublished;
    final findings = <Finding>[
      ..._ageFindings(name, version, createdAt, record.published, now),
      if (record.retracted)
        _finding(
          name,
          version,
          'RETRACTED_VERSION',
          Severity.high,
          'Version $version was retracted by its publisher',
        ),
      if (options.isDiscontinued)
        _finding(
          name,
          version,
          'DISCONTINUED',
          Severity.high,
          'Package is discontinued${options.replacedBy == null ? '' : ' '
                    '— replaced by ${options.replacedBy}'}',
        ),
      if (publisher == null)
        _finding(
          name,
          version,
          'UNVERIFIED_PUBLISHER',
          Severity.high,
          'Package has no verified publisher — maintainer identity is '
              'unverified',
        ),
      ..._popularityFindings(
        name,
        version,
        score?.likeCount,
        score?.downloadCount30Days,
      ),
      ?_qualityFinding(name, version, score?.grantedPoints, score?.maxPoints),
    ];
    return TrustInfo(
      package: name,
      version: version,
      latestVersion: listing.latestVersion,
      findings: findings,
      createdAt: createdAt,
      publishedAt: record.published,
      likeCount: score?.likeCount,
      grantedPoints: score?.grantedPoints,
      maxPoints: score?.maxPoints,
      downloadCount30Days: score?.downloadCount30Days,
      publisher: publisher,
      isDiscontinued: options.isDiscontinued,
      replacedBy: options.replacedBy,
      isRetracted: record.retracted,
    );
  }

  /// Evaluates package and release age.
  ///
  /// Returns the age findings.
  List<Finding> _ageFindings(
    String name,
    String version,
    DateTime? createdAt,
    DateTime? publishedAt,
    DateTime now,
  ) {
    final findings = <Finding>[];
    if (createdAt != null) {
      final int days = now.difference(createdAt).inDays;
      if (days < thresholds.freshPackageDays) {
        findings.add(
          _finding(
            name,
            version,
            'FRESH_PACKAGE',
            Severity.critical,
            'Package is only $days day(s) old — recently published packages '
                'are the #1 vector for supply chain attacks',
          ),
        );
      }
      final bool young =
          days >= thresholds.freshPackageDays &&
          days < thresholds.youngPackageDays;
      if (young) {
        findings.add(
          _finding(
            name,
            version,
            'YOUNG_PACKAGE',
            Severity.medium,
            'Package is $days day(s) old — relatively new, verify author '
                'reputation',
          ),
        );
      }
    }
    if (publishedAt != null) {
      final int hours = now.difference(publishedAt).inHours;
      if (hours < thresholds.freshReleaseHours) {
        findings.add(
          _finding(
            name,
            version,
            'FRESH_RELEASE',
            Severity.critical,
            'Version $version was published only ${hours}h ago — malicious '
                'versions are typically caught within 24-48 hours; wait before '
                'installing',
          ),
        );
      }
    }
    return findings;
  }

  /// Evaluates likes and downloads.
  ///
  /// Returns the popularity findings.
  List<Finding> _popularityFindings(
    String name,
    String version,
    int? likes,
    int? downloads,
  ) => <Finding>[
    if (likes != null && likes < thresholds.minLikes)
      _finding(
        name,
        version,
        'LOW_LIKES',
        Severity.medium,
        'Package has only $likes like(s) — low community endorsement',
      ),
    if (downloads != null && downloads < thresholds.minDownloads)
      _finding(
        name,
        version,
        'LOW_DOWNLOADS',
        Severity.medium,
        'Package has only $downloads download(s) in 30 days — very low '
            'usage increases the risk of typosquatting',
      ),
  ];

  /// Evaluates the pub points ratio.
  ///
  /// Returns a finding when the ratio is below the threshold, else `null`.
  Finding? _qualityFinding(
    String name,
    String version,
    int? granted,
    int? max,
  ) {
    if (granted == null || max == null || max == 0) {
      return null;
    }
    final double ratio = granted / max;
    if (ratio >= thresholds.minPointsRatio) {
      return null;
    }
    final int percent = (ratio * 100).round();
    return _finding(
      name,
      version,
      'LOW_QUALITY_SCORE',
      Severity.medium,
      'Low pub points: $granted/$max ($percent%) — may indicate poor '
          'maintenance',
    );
  }

  /// Creates a trust finding.
  ///
  /// Returns the finding.
  Finding _finding(
    String name,
    String version,
    String rule,
    Severity severity,
    String description,
  ) => Finding(
    ruleId: rule,
    source: FindingSource.trust,
    severity: severity,
    title: description,
    packageName: name,
    packageVersion: version,
    url: 'https://pub.dev/packages/$name/versions/$version',
  );
}
