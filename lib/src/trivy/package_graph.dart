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

import 'package:inspectra/src/pub/package_config.dart';
import 'package:inspectra/src/pub/package_location.dart';
import 'package:inspectra/src/trivy/pubspec_lock.dart';
import 'package:inspectra/src/util/files.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

export 'package:inspectra/src/trivy/locked_package.dart';
export 'package:inspectra/src/trivy/pubspec_lock.dart';

/// The dependency graph of a resolved package.
///
/// Built from `pubspec.lock`, `.dart_tool/package_config.json` and the
/// `pubspec.yaml` of every dependency, so it knows which packages only
/// `dev_dependencies` pull in - something the lock file alone cannot tell,
/// since it marks every indirect dependency as just `transitive`.
class PackageGraph {
  /// Creates the graph from its parts; use [load] to build one.
  PackageGraph._(
    this.rootName,
    this.lock,
    this._directories,
    this._dependencies,
    this._devDependencies,
  );

  /// Loads the graph of the package in [packageRoot], using [lockContent] as
  /// its lock file when given.
  ///
  /// The lock file and package configuration are looked up in [packageRoot]
  /// and then in its parent directories, which is where a pub workspace keeps
  /// them. Throws a [FileSystemException] when the package has not been
  /// resolved with `dart pub get`.
  static Future<PackageGraph> load(
    String packageRoot, {
    String? lockContent,
  }) async {
    final Object? pubspec = loadYaml(
      await File(p.join(packageRoot, 'pubspec.yaml')).readAsString(),
    );
    final String rootName = pubspec is Map
        ? '${pubspec['name']}'
        : p.basename(packageRoot);

    final String? lockText =
        lockContent ??
        await findUpwards(packageRoot, 'pubspec.lock')?.readAsString();
    if (lockText == null) {
      throw FileSystemException(
        'No pubspec.lock found; run "dart pub get" first.',
        packageRoot,
      );
    }
    final File? configFile = findUpwards(
      packageRoot,
      p.join('.dart_tool', 'package_config.json'),
    );
    if (configFile == null) {
      throw FileSystemException(
        'No .dart_tool/package_config.json found; run "dart pub get" first.',
        packageRoot,
      );
    }

    final Map<String, String> directories = _readPackageConfig(configFile);
    final dependencies = <String, Set<String>>{};
    for (final MapEntry(key: name, value: directory) in directories.entries) {
      dependencies[name] = _declaredDependencies(
        p.join(directory, 'pubspec.yaml'),
        dev: false,
      );
    }
    final String rootPubspec = p.join(packageRoot, 'pubspec.yaml');
    dependencies[rootName] = _declaredDependencies(rootPubspec, dev: false);

    return PackageGraph._(
      rootName,
      PubspecLock.parse(lockText),
      directories,
      dependencies,
      _declaredDependencies(rootPubspec, dev: true),
    );
  }

  /// The name of the root package.
  final String rootName;

  /// The lock file the graph was built from.
  final PubspecLock lock;

  /// The directory of every resolved package, keyed by package name.
  final Map<String, String> _directories;

  /// The `dependencies` every package declares, keyed by package name.
  final Map<String, Set<String>> _dependencies;

  /// The `dev_dependencies` the root package declares.
  final Set<String> _devDependencies;

  /// The directory of the package [name], or `null` when it is not resolved.
  String? directoryOf(String name) => _directories[name];

  /// The locked packages reachable from the root, without the root itself.
  ///
  /// Only `dependencies` are followed unless [includeDev] is set; a package's
  /// own `dev_dependencies` never are, since pub does not resolve them.
  Set<String> reachable({required bool includeDev}) {
    final List<String> pending = [
      ...?_dependencies[rootName],
      if (includeDev) ..._devDependencies,
    ];
    final seen = <String>{};
    while (pending.isNotEmpty) {
      final String name = pending.removeLast();
      if (name == rootName || !seen.add(name)) {
        continue;
      }
      pending.addAll(_dependencies[name] ?? const {});
    }
    return seen.where(lock.packages.containsKey).toSet();
  }

  /// Reads `.dart_tool/package_config.json` from [file] into the directory
  /// of every package, keyed by name; entries without a name or root are
  /// skipped.
  static Map<String, String> _readPackageConfig(File file) => <String, String>{
    for (final MapEntry<String, PackageLocation> entry in readPackageConfig(
      file,
    ).entries)
      entry.key: entry.value.root,
  };

  /// The names of the packages the pubspec at [pubspecPath] declares as
  /// `dev_dependencies` when [dev] is set, otherwise as `dependencies`.
  ///
  /// Returns an empty set when the pubspec does not exist.
  static Set<String> _declaredDependencies(
    String pubspecPath, {
    required bool dev,
  }) {
    final file = File(pubspecPath);
    if (!file.existsSync()) {
      return const {};
    }
    final Object? yaml = loadYaml(file.readAsStringSync());
    final Object? section = yaml is Map
        ? yaml[dev ? 'dev_dependencies' : 'dependencies']
        : null;
    if (section is! Map) {
      return const {};
    }
    return {for (final key in section.keys) '$key'};
  }
}
