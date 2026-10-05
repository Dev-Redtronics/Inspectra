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

import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:inspectra/src/baseline/baseline_gates.dart';
import 'package:inspectra/src/baseline/baseline_matcher.dart';
import 'package:inspectra/src/builders/build_step_config.dart';
import 'package:inspectra/src/builders/log_build_outcome.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/trivy/finding.dart';
import 'package:inspectra/src/trivy/package_graph.dart';
import 'package:inspectra/src/trivy/scans.dart';
import 'package:inspectra/src/trivy/trivy.dart';
import 'package:inspectra/src/trivy/trivy_command.dart';
import 'package:inspectra/src/util/files.dart';
import 'package:path/path.dart' as p;

/// Runs one Trivy scan as part of `dart run build_runner build`.
///
/// Only scans with `run_on_build: true` run here - by default just the
/// secret scan. Every file a scan reads goes through the build step, so the
/// scan reruns exactly when one of them changes. The JSON report is written
/// to the build cache; findings are logged, and fail the build when the scan
/// is configured to.
///
/// The filesystem scan has no builder: it reads the whole package, most of
/// which build_runner cannot see.
sealed class TrivyBuilder implements Builder {
  /// Creates the builder that runs [scan].
  const TrivyBuilder._(this.scan);

  /// The builder of the secret scan.
  ///
  /// [inPackage] decides whether a build source is a file of the package,
  /// rather than an output another builder keeps in the build cache.
  const factory TrivyBuilder.secret({bool Function(AssetId id) inPackage}) =
      _SecretScanBuilder;

  /// The builder of the license scan.
  const factory TrivyBuilder.license() = _LicenseScanBuilder;

  /// The builder of the vulnerability scan.
  const factory TrivyBuilder.vulnerability() = _VulnerabilityScanBuilder;

  /// The scan this builder runs.
  final TrivyScan scan;

  /// The report the scan writes, relative to the package root.
  String get _report => 'inspectra/trivy/${scan.name}.json';

  /// Writes the [_report] once per package.
  @override
  Map<String, List<String>> get buildExtensions => {
    r'$package$': [_report],
  };

  /// The settings of [scan] in [config].
  BuildScanConfig _select(TrivyConfig config);

  /// Runs [scan], reading its inputs through [buildStep].
  Future<ScanResult> _run(
    BuildStep buildStep,
    InspectraConfig config,
    Trivy trivy,
    String packageRoot,
  );

  /// Runs [scan] when Trivy and the scan are enabled and the scan runs on
  /// build, writes its JSON report and logs its outcome; configuration, Trivy
  /// and file system errors are logged as severe instead of failing the build
  /// with a stack trace.
  @override
  Future<void> build(BuildStep buildStep) async {
    try {
      final InspectraConfig config = await readConfig(buildStep);
      final BuildScanConfig scanConfig = _select(config.trivy);
      if (!config.trivy.enabled ||
          !scanConfig.enabled ||
          !scanConfig.runOnBuild) {
        return;
      }

      final String packageRoot = Directory.current.path;
      final ScanResult scanned = await _run(
        buildStep,
        config,
        Trivy(
          executable: config.trivy.executable,
          workingDirectory: packageRoot,
          offline: config.network.offline,
        ),
        packageRoot,
      );
      final ScanResult result = baselineScans(<ScanResult>[
        scanned,
      ], BaselineMatcher.load(config.baseline, packageRoot)).single;
      await buildStep.writeAsString(
        AssetId(buildStep.inputId.package, _report),
        const JsonEncoder.withIndent('  ').convert(result.toJson()),
      );
      logBuildOutcome(
        result.render(),
        failed: result.failed,
        findings: result.findings.isNotEmpty,
      );
    } on InspectraConfigException catch (error) {
      log.severe('$error');
    } on TrivyException catch (error) {
      log.severe('$error');
    } on FileSystemException catch (error) {
      log.severe('$error');
    } on InspectraException catch (error) {
      log.severe(error.message);
    }
  }

  /// The root package's `pubspec.lock`, read through the build step, or
  /// `null` when the package has not been resolved.
  static Future<String?> _readLock(BuildStep buildStep) async {
    final id = AssetId(buildStep.inputId.package, 'pubspec.lock');
    if (await buildStep.canRead(id)) {
      return buildStep.readAsString(id);
    }
    return findUpwards(Directory.current.path, 'pubspec.lock')?.readAsString();
  }

  /// The result of a scan that needs `pubspec.lock` in a package that has
  /// not been resolved yet.
  ScanResult _noLock() => ScanResult.skipped(
    scan: scan.name,
    reason: 'no pubspec.lock found; run "dart pub get".',
  );
}

/// Runs the Trivy secret scan over the configured files of the package.
final class _SecretScanBuilder extends TrivyBuilder {
  /// Creates the secret scan builder; [inPackage] decides which build
  /// sources are files of the package.
  const _SecretScanBuilder({this.inPackage = isInPackage})
    : super._(TrivyScan.secret);

  /// Decides whether a build source is a file of the package, rather than an
  /// output another builder keeps in the build cache.
  final bool Function(AssetId id) inPackage;

  /// The settings of the secret scan.
  @override
  BuildScanConfig _select(TrivyConfig config) => config.secret;

  /// Scans the configured files for secrets, reading them and the custom
  /// secret configuration through [buildStep] so that a change reruns it.
  @override
  Future<ScanResult> _run(
    BuildStep buildStep,
    InspectraConfig config,
    Trivy trivy,
    String packageRoot,
  ) async {
    final SecretScanConfig secret = config.trivy.secret;
    final String? secretConfig = resolveSecretConfig(
      packageRoot,
      secret.config,
    );
    if (secretConfig != null) {
      final id = AssetId(
        buildStep.inputId.package,
        posixRelative(secretConfig, from: packageRoot),
      );
      if (await buildStep.canRead(id)) {
        await buildStep.readAsBytes(id);
      }
    }
    return scanSecrets(
      trivy: trivy,
      config: secret,
      files: await _collect(buildStep, secret.include, secret.exclude),
      secretConfig: secretConfig,
    );
  }

  /// Reads every build source matching [include] and none of [exclude]
  /// through [buildStep], keyed by its path relative to the package root.
  Future<Map<String, List<int>>> _collect(
    BuildStep buildStep,
    List<String> include,
    List<String> exclude,
  ) async {
    final List<Glob> excludes = [
      for (final pattern in exclude) Glob(pattern, context: p.posix),
    ];
    final files = <String, List<int>>{};
    for (final pattern in include) {
      await for (final AssetId id in buildStep.findAssets(
        Glob(pattern, context: p.posix),
      )) {
        if (files.containsKey(id.path) ||
            !inPackage(id) ||
            excludes.any((glob) => glob.matches(id.path))) {
          continue;
        }
        files[id.path] = await buildStep.readAsBytes(id);
      }
    }
    return files;
  }
}

/// Runs the Trivy license scan over the resolved dependencies.
final class _LicenseScanBuilder extends TrivyBuilder {
  /// Creates the license scan builder.
  const _LicenseScanBuilder() : super._(TrivyScan.license);

  /// The settings of the license scan.
  @override
  BuildScanConfig _select(TrivyConfig config) => config.license;

  /// Scans the licenses of the dependencies locked in `pubspec.lock`, or
  /// skips the scan when the package has not been resolved.
  @override
  Future<ScanResult> _run(
    BuildStep buildStep,
    InspectraConfig config,
    Trivy trivy,
    String packageRoot,
  ) async {
    final String? lock = await TrivyBuilder._readLock(buildStep);
    if (lock == null) {
      return _noLock();
    }
    return scanLicenses(
      trivy: trivy,
      config: config.trivy.license,
      graph: await PackageGraph.load(packageRoot, lockContent: lock),
    );
  }
}

/// Runs the Trivy vulnerability scan over the locked dependencies.
final class _VulnerabilityScanBuilder extends TrivyBuilder {
  /// Creates the vulnerability scan builder.
  const _VulnerabilityScanBuilder() : super._(TrivyScan.vulnerability);

  /// The settings of the vulnerability scan.
  @override
  BuildScanConfig _select(TrivyConfig config) => config.vulnerability;

  /// Scans the dependencies locked in `pubspec.lock` for known
  /// vulnerabilities, or skips the scan when the package has not been
  /// resolved.
  @override
  Future<ScanResult> _run(
    BuildStep buildStep,
    InspectraConfig config,
    Trivy trivy,
    String packageRoot,
  ) async {
    final String? lock = await TrivyBuilder._readLock(buildStep);
    if (lock == null) {
      return _noLock();
    }
    final VulnerabilityScanConfig vulnerability = config.trivy.vulnerability;
    return scanVulnerabilities(
      trivy: trivy,
      config: vulnerability,
      lockContent: lock,
      graph: vulnerability.includeDevDependencies
          ? null
          : await PackageGraph.load(packageRoot, lockContent: lock),
    );
  }
}
