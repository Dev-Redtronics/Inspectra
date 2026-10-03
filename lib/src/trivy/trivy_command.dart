import 'dart:convert';
import 'dart:io';

import 'package:glob/glob.dart';
import 'package:inspectra/src/config/config_exception.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/trivy/finding.dart';
import 'package:inspectra/src/trivy/package_graph.dart';
import 'package:inspectra/src/trivy/scans.dart';
import 'package:inspectra/src/trivy/trivy.dart';
import 'package:inspectra/src/util/files.dart';
import 'package:path/path.dart' as p;

/// The scans that can be selected by name.
enum TrivyScan {
  /// Credentials in sources and configuration files.
  secret,

  /// Licenses of dependencies.
  license,

  /// Known vulnerabilities of dependencies.
  vulnerability,

  /// A plain `trivy fs` of the package.
  filesystem;

  /// Whether this scan is enabled in [config].
  bool isEnabled(TrivyConfig config) => switch (this) {
    secret => config.secret.enabled,
    license => config.license.enabled,
    vulnerability => config.vulnerability.enabled,
    filesystem => config.filesystem.enabled,
  };
}

/// Runs the enabled scans of [config] - or the ones named in [only] - on the
/// package in [packageRoot], straight from the filesystem.
///
/// Each result is also written as JSON to the configured report directory.
Future<List<ScanResult>> runTrivyScans(
  InspectraConfig config,
  String packageRoot, {
  Set<TrivyScan>? only,
}) async {
  final TrivyConfig trivyConfig = config.trivy;
  final trivy = Trivy(
    executable: trivyConfig.executable,
    workingDirectory: packageRoot,
  );
  final Set<TrivyScan> selected =
      only ??
      TrivyScan.values.where((scan) => scan.isEnabled(trivyConfig)).toSet();
  final results = <ScanResult>[];

  PackageGraph? graph;
  Future<PackageGraph> loadGraph() async =>
      graph ??= await PackageGraph.load(packageRoot);
  String? lockContent() =>
      findUpwards(packageRoot, 'pubspec.lock')?.readAsStringSync();

  for (final TrivyScan scan in TrivyScan.values.where(selected.contains)) {
    final ScanResult result = switch (scan) {
      TrivyScan.secret => await scanSecrets(
        trivy: trivy,
        config: trivyConfig.secret,
        files: collectFiles(
          packageRoot,
          trivyConfig.secret.include,
          trivyConfig.secret.exclude,
        ),
        secretConfig: resolveSecretConfig(
          packageRoot,
          trivyConfig.secret.config,
        ),
      ),
      TrivyScan.license => await scanLicenses(
        trivy: trivy,
        config: trivyConfig.license,
        graph: await loadGraph(),
      ),
      TrivyScan.vulnerability => switch (lockContent()) {
        null => ScanResult.skipped(
          scan: 'vulnerability',
          reason: 'no pubspec.lock found; run "dart pub get".',
        ),
        final String lock => await scanVulnerabilities(
          trivy: trivy,
          config: trivyConfig.vulnerability,
          lockContent: lock,
          graph: trivyConfig.vulnerability.includeDevDependencies
              ? null
              : await loadGraph(),
        ),
      },
      TrivyScan.filesystem => await scanFilesystem(
        trivy: trivy,
        config: trivyConfig.filesystem,
        packageRoot: packageRoot,
        secretConfig: resolveSecretConfig(
          packageRoot,
          trivyConfig.secret.config,
        ),
      ),
    };
    results.add(result);
    await _writeReport(
      p.join(packageRoot, trivyConfig.reportDirectory),
      result,
    );
  }
  return results;
}

/// The absolute path of the secret configuration to use, or `null` for
/// Trivy's built-in rules.
///
/// [configured] must exist when it is set; the default `trivy-secret.yaml`
/// is used only when present.
String? resolveSecretConfig(String packageRoot, String? configured) {
  final file = File(p.join(packageRoot, configured ?? defaultSecretConfig));
  if (file.existsSync()) {
    return p.normalize(file.absolute.path);
  }
  if (configured == null) {
    return null;
  }
  throw InspectraConfigException(
    'trivy.secret.config',
    'the file "$configured" does not exist.',
  );
}

/// The contents of the files under [root] that match one of [include] and
/// none of [exclude], by path relative to [root].
Map<String, List<int>> collectFiles(
  String root,
  List<String> include,
  List<String> exclude,
) {
  final List<Glob> includes = [
    for (final pattern in include) Glob(pattern, context: p.posix),
  ];
  final List<Glob> excludes = [
    for (final pattern in exclude) Glob(pattern, context: p.posix),
  ];
  bool excluded(String path) => excludes.any((glob) => glob.matches(path));

  final files = <String, List<int>>{};
  void visit(Directory directory) {
    final List<FileSystemEntity> entries = directory.listSync(
      followLinks: false,
    )..sort((a, b) => a.path.compareTo(b.path));
    for (final entry in entries) {
      final String relative = p.posix.joinAll(
        p.split(p.relative(entry.path, from: root)),
      );
      if (entry is Directory) {
        // A directory is skipped when everything below it would be excluded.
        if (!excluded('$relative/.inspectra')) {
          visit(entry);
        }
      } else if (entry is File &&
          !excluded(relative) &&
          includes.any((glob) => glob.matches(relative))) {
        files[relative] = entry.readAsBytesSync();
      }
    }
  }

  visit(Directory(root));
  return files;
}

Future<void> _writeReport(String directory, ScanResult result) async {
  final file = File(p.join(directory, '${result.scan}.json'));
  await file.parent.create(recursive: true);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(result.toJson()),
  );
}
