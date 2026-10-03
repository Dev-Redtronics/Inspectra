import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A temporary directory that is deleted after the current test.
String temporaryDirectory() {
  final Directory directory = Directory.systemTemp.createTempSync(
    'inspectra_test',
  );
  addTearDown(() => directory.deleteSync(recursive: true));
  return directory.resolveSymbolicLinksSync();
}

/// Writes [content] to [path] below [root], creating directories as needed.
void writeFile(String root, String path, String content) {
  final file = File(p.join(root, path));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

/// A resolved package as pub would leave it on disk.
class FakePackage {
  /// Creates a package [name] that depends on [dependencies].
  const FakePackage(
    this.name, {
    this.dependencies = const [],
    this.license,
    this.source = 'hosted',
  });

  /// The package name.
  final String name;

  /// The packages listed under `dependencies` in its pubspec.
  final List<String> dependencies;

  /// The content of its LICENSE file, or `null` for none.
  final String? license;

  /// Its source in the lock file.
  final String source;
}

/// Creates a resolved root package `app` in [root] with [packages] in a fake
/// pub cache next to it, as `dart pub get` would: a `pubspec.lock` and a
/// `.dart_tool/package_config.json`.
void writeResolvedPackage(
  String root, {
  required List<String> dependencies,
  required List<FakePackage> packages,
  List<String> devDependencies = const [],
}) {
  final String app = p.join(root, 'app');
  writeFile(
    app,
    'pubspec.yaml',
    _pubspec('app', dependencies, devDependencies),
  );

  final lock = StringBuffer('packages:\n');
  final config = <Map<String, Object?>>[
    {'name': 'app', 'rootUri': '../', 'packageUri': 'lib/'},
  ];
  for (final package in packages) {
    final String directory = p.join(root, 'cache', package.name);
    writeFile(
      directory,
      'pubspec.yaml',
      _pubspec(package.name, package.dependencies, const []),
    );
    if (package.license != null) {
      writeFile(directory, 'LICENSE', package.license!);
    }
    config.add({
      'name': package.name,
      'rootUri': Uri.directory(directory).toString(),
      'packageUri': 'lib/',
    });

    final kind = dependencies.contains(package.name)
        ? 'direct main'
        : devDependencies.contains(package.name)
        ? 'direct dev'
        : 'transitive';
    lock
      ..writeln('  ${package.name}:')
      ..writeln('    dependency: "$kind"')
      ..writeln('    description:')
      ..writeln('      name: ${package.name}')
      ..writeln('      url: "https://pub.dev"')
      ..writeln('    source: ${package.source}')
      ..writeln('    version: "1.0.0"');
  }
  lock.writeln('sdks:\n  dart: ">=3.0.0 <4.0.0"');
  writeFile(app, 'pubspec.lock', lock.toString());
  writeFile(
    app,
    '.dart_tool/package_config.json',
    jsonEncode({'configVersion': 2, 'packages': config}),
  );
}

String _pubspec(
  String name,
  List<String> dependencies,
  List<String> devDependencies,
) {
  final buffer = StringBuffer('name: $name\n');
  if (dependencies.isNotEmpty) {
    buffer.writeln('dependencies:');
    for (final dependency in dependencies) {
      buffer.writeln('  $dependency: any');
    }
  }
  if (devDependencies.isNotEmpty) {
    buffer.writeln('dev_dependencies:');
    for (final dependency in devDependencies) {
      buffer.writeln('  $dependency: any');
    }
  }
  return buffer.toString();
}

/// A stand-in for the Trivy executable that records how it was called.
class FakeTrivy {
  /// Creates a fake that writes [report] as its JSON report and exits with
  /// [exitCode].
  factory FakeTrivy(
    String directory, {
    Map<String, Object?> report = const {},
    int exitCode = 0,
  }) {
    final String reportFile = p.join(directory, 'canned.json');
    File(reportFile).writeAsStringSync(jsonEncode(report));
    final script = File(p.join(directory, 'trivy'))
      ..writeAsStringSync('''
#!/bin/sh
out=""
previous=""
for argument in "\$@"; do
  if [ "\$previous" = "--output" ]; then out="\$argument"; fi
  previous="\$argument"
done
eval target=\\\${\$#}
printf '%s\\n' "\$@" > "$directory/arguments.txt"
(cd "\$target" && find . -type f | sort) > "$directory/files.txt"
if [ -f "\$target/pubspec.lock" ]; then cp "\$target/pubspec.lock" "$directory/scanned.lock"; fi
cp "$reportFile" "\$out"
exit $exitCode
''');
    Process.runSync('chmod', ['+x', script.path]);
    return FakeTrivy._(script.path, directory);
  }
  FakeTrivy._(this.executable, this._directory);

  /// The path of the fake executable.
  final String executable;

  final String _directory;

  /// The arguments of the last invocation.
  List<String> get arguments =>
      File(p.join(_directory, 'arguments.txt')).readAsLinesSync();

  /// The files in the scanned directory, relative to it.
  List<String> get scannedFiles =>
      File(p.join(_directory, 'files.txt'))
          .readAsLinesSync()
          .map((line) => line.substring(2))
          .toList();

  /// The `pubspec.lock` that was scanned.
  String get scannedLock =>
      File(p.join(_directory, 'scanned.lock')).readAsStringSync();
}
