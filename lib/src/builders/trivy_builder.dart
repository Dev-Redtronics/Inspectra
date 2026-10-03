import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:inspectra/src/builders/build_step_config.dart';
import 'package:inspectra/src/config/config_exception.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
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

  String get _report => 'inspectra/trivy/${scan.name}.json';

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
      final ScanResult result = await _run(
        buildStep,
        config,
        Trivy(
          executable: config.trivy.executable,
          workingDirectory: packageRoot,
        ),
        packageRoot,
      );
      await buildStep.writeAsString(
        AssetId(buildStep.inputId.package, _report),
        const JsonEncoder.withIndent('  ').convert(result.toJson()),
      );
      if (result.failed) {
        log.severe(result.render());
      } else if (result.findings.isNotEmpty) {
        log.warning(result.render());
      } else {
        log.fine(result.render());
      }
    } on InspectraConfigException catch (error) {
      log.severe('$error');
    } on TrivyException catch (error) {
      log.severe('$error');
    } on FileSystemException catch (error) {
      log.severe('$error');
    }
  }

  /// The root package's `pubspec.lock`, read through the build step, or
  /// `null` when the package has not been resolved.
  static Future<String?> _readLock(BuildStep buildStep) async {
    final id = AssetId(buildStep.inputId.package, 'pubspec.lock');
    if (await buildStep.canRead(id)) {
      return buildStep.readAsString(id);
    }
    // In a pub workspace the lock file lives in the workspace root.
    return findUpwards(Directory.current.path, 'pubspec.lock')?.readAsString();
  }

  ScanResult _noLock() => ScanResult.skipped(
    scan: scan.name,
    reason: 'no pubspec.lock found; run "dart pub get".',
  );
}

final class _SecretScanBuilder extends TrivyBuilder {
  const _SecretScanBuilder({this.inPackage = isInPackage})
    : super._(TrivyScan.secret);

  final bool Function(AssetId id) inPackage;

  @override
  BuildScanConfig _select(TrivyConfig config) => config.secret;

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
      // Read through the build step so that editing the rules reruns the
      // scan - provided the file is one of the package's build sources.
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

final class _LicenseScanBuilder extends TrivyBuilder {
  const _LicenseScanBuilder() : super._(TrivyScan.license);

  @override
  BuildScanConfig _select(TrivyConfig config) => config.license;

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

final class _VulnerabilityScanBuilder extends TrivyBuilder {
  const _VulnerabilityScanBuilder() : super._(TrivyScan.vulnerability);

  @override
  BuildScanConfig _select(TrivyConfig config) => config.vulnerability;

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
