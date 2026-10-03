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
class TrivyBuilder implements Builder {
  /// Creates a builder for [scan], which is one of [TrivyScan.secret],
  /// [TrivyScan.license] or [TrivyScan.vulnerability].
  TrivyBuilder(this.scan)
    : assert(
        scan != TrivyScan.filesystem,
        'The filesystem scan only runs from the command line.',
      );

  /// The scan this builder runs.
  final TrivyScan scan;

  String get _report => 'inspectra/trivy/${scan.name}.json';

  @override
  Map<String, List<String>> get buildExtensions => {
    r'$package$': [_report],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    try {
      final InspectraConfig config = await readConfig(buildStep);
      final ScanConfig scanConfig = switch (scan) {
        TrivyScan.secret => config.trivy.secret,
        TrivyScan.license => config.trivy.license,
        TrivyScan.vulnerability => config.trivy.vulnerability,
        TrivyScan.filesystem => config.trivy.filesystem,
      };
      if (!config.trivy.enabled ||
          !scanConfig.enabled ||
          !scanConfig.runOnBuild) {
        return;
      }

      final ScanResult result = await _run(buildStep, config);
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
    }
  }

  Future<ScanResult> _run(BuildStep buildStep, InspectraConfig config) async {
    final String package = buildStep.inputId.package;
    final String packageRoot = Directory.current.path;
    final trivy = Trivy(
      executable: config.trivy.executable,
      workingDirectory: packageRoot,
    );

    switch (scan) {
      case TrivyScan.secret:
        final SecretScanConfig secret = config.trivy.secret;
        final String? secretConfig = resolveSecretConfig(
          packageRoot,
          secret.config,
        );
        if (secretConfig != null) {
          // Read through the build step so that editing the rules reruns
          // the scan.
          final id = AssetId(
            package,
            p.posix.joinAll(
              p.split(p.relative(secretConfig, from: packageRoot)),
            ),
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
      case TrivyScan.license:
        final String? lock = await _readLock(buildStep);
        if (lock == null) {
          return _noLock(scan);
        }
        return scanLicenses(
          trivy: trivy,
          config: config.trivy.license,
          graph: await PackageGraph.load(packageRoot, lockContent: lock),
        );
      case TrivyScan.vulnerability:
        final String? lock = await _readLock(buildStep);
        if (lock == null) {
          return _noLock(scan);
        }
        final VulnerabilityScanConfig vulnerability =
            config.trivy.vulnerability;
        return scanVulnerabilities(
          trivy: trivy,
          config: vulnerability,
          lockContent: lock,
          graph: vulnerability.includeDevDependencies
              ? null
              : await PackageGraph.load(packageRoot, lockContent: lock),
        );
      case TrivyScan.filesystem:
        throw StateError(
          'The filesystem scan only runs from the command line.',
        );
    }
  }

  static Future<Map<String, List<int>>> _collect(
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
            excludes.any((glob) => glob.matches(id.path))) {
          continue;
        }
        files[id.path] = await buildStep.readAsBytes(id);
      }
    }
    return files;
  }

  static Future<String?> _readLock(BuildStep buildStep) async {
    final id = AssetId(buildStep.inputId.package, 'pubspec.lock');
    if (await buildStep.canRead(id)) {
      return buildStep.readAsString(id);
    }
    // In a pub workspace the lock file lives in the workspace root.
    return findUpwards(Directory.current.path, 'pubspec.lock')?.readAsString();
  }

  static ScanResult _noLock(TrivyScan scan) => ScanResult.skipped(
    scan: scan.name,
    reason: 'no pubspec.lock found; run "dart pub get".',
  );
}
