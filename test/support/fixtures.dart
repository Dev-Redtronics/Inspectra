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

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fake_package.dart';

export 'fake_package.dart';
export 'fake_trivy.dart';

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

/// The content of a `pubspec.yaml` of the package [name] with the given
/// [dependencies] and [devDependencies], all of them `any`.
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
