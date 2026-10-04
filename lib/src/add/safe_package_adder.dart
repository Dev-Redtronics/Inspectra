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

import 'dart:io';

import 'package:inspectra/src/add/add_report.dart';
import 'package:inspectra/src/config/inspect_config.dart';
import 'package:inspectra/src/host/host_platform.dart';
import 'package:inspectra/src/inspect/inspection_report.dart';
import 'package:inspectra/src/inspect/inspection_result.dart';
import 'package:inspectra/src/inspect/package_inspector.dart';
import 'package:inspectra/src/io/process_outcome.dart';
import 'package:inspectra/src/io/process_runner.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/model/source_location.dart';
import 'package:inspectra/src/policy/filter_outcome.dart';
import 'package:inspectra/src/policy/finding_filter.dart';
import 'package:inspectra/src/pub/package_name.dart';
import 'package:inspectra/src/pub/pub_package.dart';
import 'package:inspectra/src/pub/pub_repository_client.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/pub/pubspec_parser.dart';
import 'package:inspectra/src/typosquat/typosquat_detector.dart';
import 'package:path/path.dart' as p;

/// Audits a package and adds exactly the audited version to a project.
///
/// The package is blocked when it looks like a typosquat (HIGH or worse),
/// when its trust assessment has a CRITICAL finding, or when its source
/// inspection reaches the configured risk score. `--force` only overrides
/// such findings; an incomplete verification (network failure, missing
/// archive) always aborts.
///
/// The exact inspected version is passed to `pub add` as `name:version`, so
/// the resolver cannot pick a different, unaudited release.
final class SafePackageAdder {
  /// Creates an adder.
  const SafePackageAdder({
    required this.repository,
    required this.inspector,
    required this.typosquatDetector,
    required this.processRunner,
    required this.host,
    required this.config,
  });

  /// The pub repository client.
  final PubRepositoryClient repository;

  /// The package inspector.
  final PackageInspector inspector;

  /// The typosquat detector.
  final TyposquatDetector typosquatDetector;

  /// Runs `dart pub add` or `flutter pub add`.
  final ProcessRunner processRunner;

  /// The host platform; Windows needs a shell to start `.bat` shims.
  final HostPlatform host;

  /// The inspector configuration with the fail score.
  final InspectConfig config;

  /// Audits [name] (at [version], or the latest version) and adds it to the
  /// project in [projectDirectory].
  ///
  /// [dev] adds it to `dev_dependencies`, [force] installs despite findings,
  /// [dryRun] never installs, [filter] applies ignore rules and [onStatus]
  /// receives progress messages.
  ///
  /// Returns the report.
  ///
  /// Throws an [InvalidUsageException] for invalid names, versions or
  /// unknown packages, an [InvalidInputException] when the project has no
  /// readable `pubspec.yaml`, and an [UnavailableException] when the audit
  /// cannot be completed or `pub add` fails.
  Future<AddReport> add({
    required String name,
    required String projectDirectory,
    required FindingFilter filter,
    required void Function(String message) onStatus,
    String? version,
    bool dev = false,
    bool force = false,
    bool dryRun = false,
  }) async {
    PackageName.validate(name);
    if (version != null) {
      PackageName.validateExactVersion(version);
    }
    final String pubspecPath = p.join(projectDirectory, 'pubspec.yaml');
    final Pubspec pubspec = const PubspecParser().parseFile(pubspecPath);
    onStatus('Checking typosquatting indicators...');
    final List<Finding> typosquat = typosquatDetector.analyze(<String>[
      name,
    ], locate: (_) => const SourceLocation('pubspec.yaml'));
    onStatus('Fetching package metadata...');
    final PubPackage? listing = await repository.package(name);
    if (listing == null) {
      throw InvalidUsageException(
        'Package "$name" was not found on ${repository.baseUrl}.',
      );
    }
    final String target = version ?? listing.latestVersion;
    final InspectionResult inspection = await inspector.inspect(
      name,
      target,
      onStatus: onStatus,
      knownListing: listing,
    );
    final FilterOutcome outcome = filter.apply(<Finding>[
      ...typosquat,
      ...inspection.findings,
    ]);
    final report = InspectionReport(
      result: inspection,
      findings: outcome.kept,
      failScore: config.failScore,
      suppressedCount: outcome.suppressed.length,
    );
    final List<String> reasons = _blockReasons(report);
    final bool blocked = reasons.isNotEmpty;
    final bool mayInstall = !dryRun && (!blocked || force);
    if (!mayInstall) {
      return AddReport(
        package: name,
        version: target,
        dev: dev,
        inspection: report,
        blockReasons: reasons,
        installed: false,
        forced: force,
        dryRun: dryRun,
      );
    }
    onStatus('Running pub add $name:$target...');
    final String output = await _pubAdd(
      pubspec.isFlutterProject ? 'flutter' : 'dart',
      name,
      target,
      dev: dev,
      projectDirectory: projectDirectory,
    );
    return AddReport(
      package: name,
      version: target,
      dev: dev,
      inspection: report,
      blockReasons: reasons,
      installed: true,
      forced: force,
      dryRun: dryRun,
      pubOutput: output,
    );
  }

  /// Collects the reasons why the inspected package must not be installed.
  ///
  /// Returns the reasons; empty when the package passed.
  List<String> _blockReasons(InspectionReport report) {
    final List<Finding> findings = report.findings;
    final Iterable<Finding> typosquat = findings.where(
      (f) =>
          f.source == FindingSource.typosquat &&
          f.severity.isAtLeast(Severity.high),
    );
    final Iterable<Finding> untrusted = findings.where(
      (f) => f.source == FindingSource.trust && f.severity == Severity.critical,
    );
    final Object? matched =
        typosquat.firstOrNull?.attributes['matchedPublicPackage'];
    final typosquatReason =
        'The package name looks like a typosquat of '
        '"$matched".';
    final trustReason =
        'The trust assessment found: '
        '${untrusted.firstOrNull?.title}.';
    final riskReason =
        'The source inspection risk score is '
        '${report.riskScore}/100 (limit ${config.failScore}).';
    return <String>[
      if (typosquat.isNotEmpty) typosquatReason,
      if (untrusted.isNotEmpty) trustReason,
      if (report.riskScore >= config.failScore) riskReason,
    ];
  }

  /// Runs `<executable> pub add` for exactly [version] of [name].
  ///
  /// Returns the combined output.
  ///
  /// Throws an [UnavailableException] when the tool is missing or fails.
  Future<String> _pubAdd(
    String executable,
    String name,
    String version, {
    required bool dev,
    required String projectDirectory,
  }) async {
    final arguments = <String>[
      'pub',
      'add',
      if (dev) '--dev',
      '$name:$version',
    ];
    try {
      final ProcessOutcome outcome = await processRunner.run(
        executable,
        arguments,
        workingDirectory: projectDirectory,
        runInShell: host.isWindows,
      );
      final String output = '${outcome.stdout}\n${outcome.stderr}'.trim();
      if (!outcome.succeeded) {
        throw UnavailableException(
          '"$executable ${arguments.join(' ')}" failed with exit code '
          '${outcome.exitCode}:\n$output',
        );
      }
      return output;
    } on ProcessException {
      throw UnavailableException(
        '"$executable" could not be started. Make sure the Dart or Flutter '
        'SDK is on the PATH.',
      );
    }
  }
}
