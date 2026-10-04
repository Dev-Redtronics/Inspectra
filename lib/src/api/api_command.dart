import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:glob/glob.dart';
import 'package:inspectra/src/api/api_diff.dart';
import 'package:inspectra/src/api/api_renderer.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/util/files.dart';
import 'package:path/path.dart' as p;

/// Renders the public API of the package in [packageRoot] with the analyzer
/// directly, for use outside of build_runner.
///
/// The result is identical to what the `inspectra:api` builder writes.
Future<String> renderPackageApi(
  InspectraConfig config,
  String packageRoot,
) async {
  final String root = p.normalize(p.absolute(packageRoot));
  final String lib = p.join(root, 'lib');
  final List<Glob> ignored = [
    for (final pattern in config.api.ignoredLibraries)
      Glob(pattern, context: p.posix),
  ];

  final paths = <String>[
    if (Directory(lib).existsSync())
      for (final entity in Directory(lib).listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.dart'))
          posixRelative(entity.path, from: root),
  ]..sort();

  final collection = AnalysisContextCollection(includedPaths: [lib]);
  try {
    final AnalysisSession session = collection.contextFor(lib).currentSession;
    final libraries = <LibraryElement>[];
    for (final path in paths) {
      if (path.startsWith('lib/src/') ||
          ignored.any((glob) => glob.matches(path))) {
        continue;
      }
      final uri =
          'package:${config.packageName}/${path.substring('lib/'.length)}';
      final SomeLibraryElementResult result = await session.getLibraryByUri(
        uri,
      );
      if (result is LibraryElementResult) {
        libraries.add(result.element);
      }
    }
    return renderApi(
      libraries,
      nonPublicAnnotations: config.api.nonPublicAnnotations,
    );
  } finally {
    await collection.dispose();
  }
}

/// The outcome of comparing the public API with its committed dump.
class ApiCheckResult {
  /// Creates the outcome.
  const ApiCheckResult({
    required this.dumpPath,
    required this.diff,
    required this.missing,
  });

  /// The dump file, relative to the package root.
  final String dumpPath;

  /// How the API differs from the dump, or `null` when it matches.
  final String? diff;

  /// Whether no dump has been recorded yet.
  final bool missing;

  /// Whether the check failed.
  bool get failed => missing || diff != null;

  /// A readable summary for the console.
  String render() {
    if (missing) {
      return 'No public API dump has been recorded yet at $dumpPath.\n\n'
          'Create it and commit the result:\n\n'
          '    dart run inspectra api dump';
    }
    if (diff == null) {
      return 'The public API matches $dumpPath.';
    }
    return 'The public API changed.\n\n$diff\n\n'
        'If the change is intended, record it and commit the result:\n\n'
        '    dart run inspectra api dump';
  }
}

/// Writes the public API of the package in [packageRoot] to its dump and
/// returns the dump's path.
Future<String> dumpApi(InspectraConfig config, String packageRoot) async {
  final file = File(p.join(packageRoot, config.api.output));
  await file.parent.create(recursive: true);
  await file.writeAsString(await renderPackageApi(config, packageRoot));
  return config.api.output;
}

/// Compares the public API of the package in [packageRoot] with its dump.
Future<ApiCheckResult> checkApi(
  InspectraConfig config,
  String packageRoot,
) async {
  final file = File(p.join(packageRoot, config.api.output));
  if (!file.existsSync()) {
    return ApiCheckResult(
      dumpPath: config.api.output,
      diff: null,
      missing: true,
    );
  }
  final String actual = await renderPackageApi(config, packageRoot);
  return ApiCheckResult(
    dumpPath: config.api.output,
    diff: diffApi(expected: await file.readAsString(), actual: actual),
    missing: false,
  );
}
