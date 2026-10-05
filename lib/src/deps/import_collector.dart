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

import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:inspectra/src/deps/package_imports.dart';
import 'package:inspectra/src/pub/project_discovery.dart';
import 'package:inspectra/src/util/files.dart';
import 'package:path/path.dart' as p;

/// Collects the packages that the Dart files of a package import.
///
/// The files are parsed without resolution, so no `dart pub get` is
/// needed. Imports, exports and conditional imports count; nested packages
/// with a `pubspec.yaml` of their own, such as an `example/` package, are
/// left to themselves.
final class ImportCollector {
  /// Creates a collector.
  const ImportCollector();

  /// The directories of the code that runs in the package's users.
  static const runtimeDirectories = <String>['lib', 'bin'];

  /// The directories of code that only runs during development.
  static const developmentDirectories = <String>[
    'test',
    'tool',
    'integration_test',
    'test_driver',
    'example',
    'benchmark',
  ];

  /// The directories that never hold sources of the package.
  static const _excluded = <String>[
    '**/.dart_tool/**',
    '**/build/**',
    '**/.git/**',
  ];

  /// An import of a package library.
  static final _packageUri = RegExp('^package:([a-zA-Z0-9_]+)/');

  /// Collects the imports of the package in [packageRoot].
  ///
  /// Returns the imported packages of the runtime and development code.
  PackageImports collect(String packageRoot) {
    final List<String> nested = ProjectDiscovery(packageRoot)
        .find('pubspec.yaml', recursive: true)
        .map(p.dirname)
        .where((directory) => !p.equals(directory, packageRoot))
        .toList();
    return PackageImports(
      runtime: _imports(packageRoot, runtimeDirectories, nested),
      development: _imports(packageRoot, developmentDirectories, nested),
    );
  }

  /// Collects the imports of the Dart files in [directories] of
  /// [packageRoot], outside of the [nested] packages.
  ///
  /// Returns the package names.
  Set<String> _imports(
    String packageRoot,
    List<String> directories,
    List<String> nested,
  ) {
    final List<String> files = listFiles(packageRoot, <String>[
      for (final directory in directories) '$directory/**.dart',
    ], _excluded);
    final packages = <String>{};
    for (final relative in files) {
      final String path = p.join(packageRoot, relative);
      final bool isNested = nested.any(
        (directory) => p.isWithin(directory, path),
      );
      if (!isNested) {
        packages.addAll(packagesOf(File(path).readAsStringSync(), path));
      }
    }
    return packages;
  }

  /// Parses the Dart [source] of the file at [path].
  ///
  /// Returns the packages its imports and exports refer to, including the
  /// alternatives of conditional imports.
  static Set<String> packagesOf(String source, String path) {
    final ParseStringResult result = parseString(
      content: source,
      path: path,
      throwIfDiagnostics: false,
    );
    final packages = <String>{};
    for (final NamespaceDirective directive
        in result.unit.directives.whereType<NamespaceDirective>()) {
      final uris = <String?>[
        directive.uri.stringValue,
        for (final Configuration configuration in directive.configurations)
          configuration.uri.stringValue,
      ];
      for (final uri in uris) {
        final String? name = uri == null
            ? null
            : _packageUri.firstMatch(uri)?.group(1);
        if (name != null) {
          packages.add(name);
        }
      }
    }
    return packages;
  }
}
