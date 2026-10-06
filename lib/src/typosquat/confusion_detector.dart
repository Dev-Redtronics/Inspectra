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

import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/model/source_location.dart';
import 'package:inspectra/src/pub/dependency_kind.dart';
import 'package:inspectra/src/pub/dependency_spec.dart';
import 'package:inspectra/src/pub/lockfile.dart';
import 'package:inspectra/src/pub/pub_package.dart';
import 'package:inspectra/src/pub/pub_repository_client.dart';
import 'package:inspectra/src/util/bounded_concurrency.dart';
import 'package:pub_semver/pub_semver.dart';

/// Detects dependency confusion risks.
///
/// Rules:
///
/// * `DEPENDENCY_CONFUSION` (HIGH): a dependency served by a private
///   registry whose name also exists on the public pub.dev. If the private
///   registry is ever bypassed or proxies pub.dev, the public package wins.
/// * `SUSPICIOUS_VERSION` (MEDIUM): a public package whose latest major
///   version is above fifty, a typical sign of version inflation used to
///   win resolution against a private package.
///
/// Failures are not silently swallowed: if the public repository cannot be
/// queried the scan reports the outage.
final class ConfusionDetector {
  /// Creates a detector querying the public repository [publicRepository]
  /// with at most [concurrency] requests in flight; [mirrorUrl] is the
  /// configured pub repository, treated as public.
  const ConfusionDetector({
    required this.publicRepository,
    required this.concurrency,
    required this.mirrorUrl,
  });

  /// The public repository client.
  final PubRepositoryClient publicRepository;

  /// The maximum number of concurrent requests.
  final int concurrency;

  /// The configured pub repository URL.
  final String mirrorUrl;

  /// The major version above which a release looks inflated.
  static const inflatedMajor = 50;

  /// Analyses the hosted [dependencies]; [locate] maps a name to its
  /// declaration.
  ///
  /// Returns the findings.
  Future<List<Finding>> analyze(
    Map<String, DependencySpec> dependencies, {
    required SourceLocation Function(String name) locate,
  }) async {
    final List<MapEntry<String, DependencySpec>> hosted = dependencies.entries
        .where((entry) => entry.value.kind == DependencyKind.hosted)
        .toList();
    final List<Finding?> results = await mapWithConcurrency(
      hosted,
      concurrency,
      (entry) => _check(entry.key, entry.value, locate(entry.key)),
    );
    return results.nonNulls.toList();
  }

  /// Checks one hosted dependency.
  ///
  /// Returns a finding, or `null`.
  Future<Finding?> _check(
    String name,
    DependencySpec spec,
    SourceLocation location,
  ) async {
    final bool isPrivate = !Lockfile.isPublicRegistry(
      spec.hostedUrl,
      mirrorUrl,
    );
    final PubPackage? listing = await publicRepository.package(name);
    if (listing == null) {
      return null;
    }
    if (isPrivate) {
      return _finding(
        name,
        'DEPENDENCY_CONFUSION',
        Severity.high,
        'Package "$name" is served by the private registry '
            '${spec.hostedUrl}, but pub.dev publishes a package with the same '
            'name (latest ${listing.latestVersion}) — a misconfigured or '
            'proxying registry would install the public one',
        listing.latestVersion,
        location,
      );
    }
    final int? major = _major(listing.latestVersion);
    if (major == null || major <= inflatedMajor) {
      return null;
    }
    return _finding(
      name,
      'SUSPICIOUS_VERSION',
      Severity.medium,
      'Package "$name" has suspicious version "${listing.latestVersion}" — '
          'unusually high version numbers may indicate a version inflation '
          'attack (dependency confusion)',
      listing.latestVersion,
      location,
    );
  }

  /// Extracts the major version of [version].
  ///
  /// Returns the major version, or `null` when unparsable.
  int? _major(String version) {
    try {
      return Version.parse(version).major;
    } on FormatException {
      return null;
    }
  }

  /// Creates a confusion finding.
  ///
  /// Returns the finding.
  Finding _finding(
    String name,
    String rule,
    Severity severity,
    String description,
    String publicVersion,
    SourceLocation location,
  ) => Finding(
    ruleId: rule,
    source: FindingSource.confusion,
    severity: severity,
    title: description,
    location: location,
    packageName: name,
    url: 'https://pub.dev/packages/$name',
    attributes: <String, Object?>{'publicVersion': publicVersion},
  );
}
