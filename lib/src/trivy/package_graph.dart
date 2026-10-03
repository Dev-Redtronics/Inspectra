import 'dart:convert';
import 'dart:io';

import 'package:inspectra/src/util/files.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// One package of a `pubspec.lock`.
class LockedPackage {
  /// Creates a locked package.
  const LockedPackage({
    required this.name,
    required this.version,
    required this.source,
    required this.dependency,
    required this.json,
  });

  /// The package name.
  final String name;

  /// The resolved version.
  final String version;

  /// Where it comes from: `hosted`, `git`, `path` or `sdk`.
  final String source;

  /// How the root depends on it: `direct main`, `direct dev`,
  /// `direct overridden` or `transitive`.
  final String dependency;

  /// The entry as it appears in the lock file.
  final Map<String, Object?> json;

  /// Whether the package is third-party code fetched by pub, as opposed to a
  /// package of the same repository or of the SDK.
  bool get isExternal => source == 'hosted' || source == 'git';
}

/// A parsed `pubspec.lock`.
class PubspecLock {
  /// Creates a lock from its packages.
  const PubspecLock(this.packages);

  /// Parses the content of a `pubspec.lock`.
  factory PubspecLock.parse(String content) {
    final Object? yaml = loadYaml(content);
    final Object? packages = yaml is Map ? yaml['packages'] : null;
    final result = <String, LockedPackage>{};
    if (packages is Map) {
      for (final MapEntry(:key, :value) in packages.entries) {
        if (key is! String || value is! Map) {
          continue;
        }
        final json = jsonDecode(jsonEncode(value)) as Map<String, Object?>;
        result[key] = LockedPackage(
          name: key,
          version: '${value['version'] ?? ''}',
          source: '${value['source'] ?? ''}',
          dependency: '${value['dependency'] ?? ''}',
          json: json,
        );
      }
    }
    return PubspecLock(Map.unmodifiable(result));
  }

  /// The locked packages by name.
  final Map<String, LockedPackage> packages;

  /// A lock file holding only the packages in [names].
  ///
  /// It is written as JSON, which every YAML parser - Trivy's included -
  /// reads as YAML.
  String retain(Iterable<String> names) {
    final Map<String, Map<String, Object?>> retained = {
      for (final name in names.toList()..sort())
        if (packages[name] case final package?) name: package.json,
    };
    return const JsonEncoder.withIndent('  ')
        .convert({'packages': retained, 'sdks': <String, Object?>{}});
  }
}

/// The dependency graph of a resolved package.
///
/// Built from `pubspec.lock`, `.dart_tool/package_config.json` and the
/// `pubspec.yaml` of every dependency, so it knows which packages only
/// `dev_dependencies` pull in - something the lock file alone cannot tell,
/// since it marks every indirect dependency as just `transitive`.
class PackageGraph {
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
  /// them.
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
      throw StateError(
        'No pubspec.lock found for $packageRoot. Run "dart pub get" first.',
      );
    }
    final File? configFile = findUpwards(
      packageRoot,
      p.join('.dart_tool', 'package_config.json'),
    );
    if (configFile == null) {
      throw StateError(
        'No .dart_tool/package_config.json found for $packageRoot. Run "dart pub get" first.',
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

  final Map<String, String> _directories;
  final Map<String, Set<String>> _dependencies;
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

  static Map<String, String> _readPackageConfig(File file) {
    final Object? json = jsonDecode(file.readAsStringSync());
    final Object? packages = json is Map ? json['packages'] : null;
    final result = <String, String>{};
    if (packages is! List) {
      return result;
    }
    final Uri base = file.uri;
    for (final Object? package in packages) {
      if (package is! Map) {
        continue;
      }
      final Object? name = package['name'];
      final Object? rootUri = package['rootUri'];
      if (name is! String || rootUri is! String) {
        continue;
      }
      final Uri uri = base.resolve(
        rootUri.endsWith('/') ? rootUri : '$rootUri/',
      );
      result[name] = p.normalize(uri.toFilePath());
    }
    return result;
  }

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
