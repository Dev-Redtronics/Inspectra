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

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:glob/glob.dart';
import 'package:inspectra/src/api/api_check_result.dart';
import 'package:inspectra/src/api/api_diff.dart';
import 'package:inspectra/src/api/api_renderer.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/util/files.dart';
import 'package:path/path.dart' as p;

export 'package:inspectra/src/api/api_check_result.dart';

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
