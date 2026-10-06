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

import 'package:inspectra/src/config/dependency_policy_config.dart';
import 'package:inspectra/src/config/libyear_scope.dart';
import 'package:inspectra/src/deps/outdated_outcome.dart';
import 'package:inspectra/src/deps/policy_source.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/model/source_location.dart';
import 'package:inspectra/src/pub/lockfile.dart';
import 'package:inspectra/src/pub/lockfile_entry.dart';
import 'package:inspectra/src/pub/pub_package.dart';
import 'package:inspectra/src/pub/pub_version.dart';
import 'package:inspectra/src/report/snippet_sanitizer.dart';
import 'package:inspectra/src/util/bounded_concurrency.dart';
import 'package:pub_semver/pub_semver.dart';

/// Checks how far the dependencies of a package are behind their latest
/// releases: `dependency_policy.max_major_behind` and `max_libyear`. Both
/// need the version listings of the package registry.
final class OutdatedPolicy {
  /// Creates the check of [config]; [lookup] fetches the version listing
  /// of a package from a registry, at most [concurrency] at a time, and
  /// [defaultRegistry] is the registry of packages without a `hosted:` URL
  /// and of packages from pub.dev, which may be a mirror.
  const OutdatedPolicy({
    required this.config,
    required this.lookup,
    required this.defaultRegistry,
    this.concurrency = 8,
  });

  /// The policy settings.
  final DependencyPolicyConfig config;

  /// Fetches the listing of a package from a registry, or `null` when the
  /// registry does not know it.
  final Future<PubPackage?> Function(String name, String registry) lookup;

  /// The registry of hosted packages without a `hosted:` URL.
  final String defaultRegistry;

  /// How many listings are fetched at the same time.
  final int concurrency;

  /// Checks the package described by [source] against its lockfile.
  ///
  /// Returns the findings and the libyears; nothing without a lockfile of
  /// the package's own.
  ///
  /// Throws an [UnavailableException] when a registry cannot be queried.
  Future<OutdatedOutcome> check(PolicySource source) async {
    final Lockfile? lockfile = source.lockfile;
    final bool applies =
        config.hasOutdatedRules && lockfile != null && source.ownsLockfile;
    if (!applies) {
      return const OutdatedOutcome(findings: <Finding>[]);
    }
    final all = config.libyearScope == LibyearScope.all;
    final List<LockfileEntry> counted = lockfile.packages
        .where((entry) => entry.isHosted && (all || entry.isDirect))
        .toList();
    final List<PubPackage?> listings = await mapWithConcurrency(
      counted,
      concurrency,
      (entry) => lookup(entry.name, _registryOf(entry)),
    );
    final findings = <Finding>[];
    final contributions = <(String, double)>[];
    for (var index = 0; index < counted.length; index++) {
      final LockfileEntry entry = counted[index];
      final PubPackage? listing = listings[index];
      if (listing == null) {
        continue;
      }
      final Finding? behind = _behind(source, entry, listing);
      if (behind != null) {
        findings.add(behind);
      }
      final double? years = _libyears(entry, listing);
      if (years != null && years > 0) {
        contributions.add((entry.name, years));
      }
    }
    final double total = contributions.fold(
      0,
      (sum, contribution) => sum + contribution.$2,
    );
    final double? limit = config.maxLibyear;
    if (limit != null && total > limit) {
      findings.add(_libyearFinding(source, total, limit, contributions));
    }
    return OutdatedOutcome(findings: findings, libyears: total);
  }

  /// Returns the registry to ask about [entry]: its own, or the configured
  /// registry for pub.dev, so that a mirror of pub.dev is used.
  String _registryOf(LockfileEntry entry) {
    final String? hosted = entry.hostedUrl;
    return hosted == null || Lockfile.isPublicRegistry(hosted, defaultRegistry)
        ? defaultRegistry
        : hosted;
  }

  /// Reports the direct dependency [entry] when it is more breaking
  /// releases behind [listing]'s latest version than allowed.
  ///
  /// Returns the finding, or `null`.
  Finding? _behind(
    PolicySource source,
    LockfileEntry entry,
    PubPackage listing,
  ) {
    final int? maximum = config.maxMajorBehind;
    final Version? locked = _parse(entry.version);
    final Version? latest = _parse(listing.latestVersion);
    final bool measurable =
        maximum != null && entry.isDirect && locked != null && latest != null;
    if (!measurable || latest <= locked) {
      return null;
    }
    final int behind = breakingReleasesBetween(
      locked,
      latest,
      listing.versions,
    );
    if (behind <= maximum) {
      return null;
    }
    final section = source.pubspec.dependencies.containsKey(entry.name)
        ? 'dependencies'
        : 'dev_dependencies';
    return _finding(
      'OUTDATED_MAJOR',
      '${entry.name} is $behind breaking release(s) behind ($locked, latest '
          '$latest)',
      'dependency_policy.max_major_behind allows $maximum. Every skipped '
          'breaking release makes the upgrade harder and leaves fixes '
          'behind; "dart pub upgrade --major-versions ${entry.name}" raises '
          'the constraint.',
      source.locator.entry(section, entry.name),
      package: entry.name,
      version: '$locked',
      fixed: '$latest',
      attributes: <String, Object?>{'behind': behind},
    );
  }

  /// Measures how long [entry]'s locked version was superseded by
  /// [listing]'s latest one.
  ///
  /// Returns the years between their publication, or `null` when a date
  /// is missing.
  double? _libyears(LockfileEntry entry, PubPackage listing) {
    final DateTime? locked = listing.find(entry.version)?.published;
    final DateTime? latest = listing.find(listing.latestVersion)?.published;
    if (locked == null || latest == null) {
      return null;
    }
    return latest.difference(locked).inHours / (24 * 365.25);
  }

  /// Reports that the dependencies add up to [total] libyears, more than
  /// the [limit], naming the largest [contributions].
  ///
  /// Returns the finding.
  Finding _libyearFinding(
    PolicySource source,
    double total,
    double limit,
    List<(String, double)> contributions,
  ) {
    final largest = <(String, double)>[...contributions]
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final String names = largest
        .take(5)
        .map((entry) => '${entry.$1} (${_years(entry.$2)})')
        .join(', ');
    return _finding(
      'LIBYEAR_EXCEEDED',
      'The dependencies are ${_years(total)} libyears behind, more than '
          '${_years(limit)}',
      'A libyear is a year between the release in pubspec.lock and the '
          'latest release of a dependency. The largest: $names. Upgrade '
          'them with "dart pub upgrade".',
      source.locator.topLevel('name'),
      package: source.pubspec.name,
      attributes: <String, Object?>{
        'libyears': double.parse(total.toStringAsFixed(2)),
      },
    );
  }

  /// Formats [years] with one decimal.
  static String _years(double years) => years.toStringAsFixed(1);

  /// Parses [text] as a version.
  ///
  /// Returns the version, or `null` when it is none.
  static Version? _parse(String text) {
    try {
      return Version.parse(text);
    } on FormatException {
      return null;
    }
  }

  /// Creates a finding of the source [FindingSource.pubspec].
  ///
  /// Returns the finding.
  static Finding _finding(
    String ruleId,
    String title,
    String description,
    SourceLocation location, {
    String? package,
    String? version,
    String? fixed,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) => Finding(
    ruleId: ruleId,
    source: FindingSource.pubspec,
    severity: Severity.medium,
    title: SnippetSanitizer.sanitize(title),
    description: SnippetSanitizer.escape(description),
    location: location,
    packageName: package,
    packageVersion: version,
    fixedVersion: fixed,
    attributes: <String, Object?>{'policy': true, ...attributes},
  );
}

/// Counts the breaking release lines among the stable, not retracted
/// [versions] after [locked] up to [latest]: majors from 1.0.0 on, minors
/// before it, as pub's caret constraints do.
///
/// Returns the number of breaking releases [locked] is behind.
int breakingReleasesBetween(
  Version locked,
  Version latest,
  List<PubVersion> versions,
) {
  final lines = <String>{};
  for (final published in versions) {
    final Version? version = OutdatedPolicy._parse(published.version);
    final bool counts =
        version != null &&
        !version.isPreRelease &&
        !published.retracted &&
        version > locked &&
        version <= latest &&
        _lineOf(version) != _lineOf(locked);
    if (counts) {
      lines.add(_lineOf(version));
    }
  }
  return lines.length;
}

/// Names the breaking release line of [version]: its major, or `0.minor`
/// before 1.0.0.
///
/// Returns the name of the line.
String _lineOf(Version version) =>
    version.major > 0 ? '${version.major}' : '0.${version.minor}';
