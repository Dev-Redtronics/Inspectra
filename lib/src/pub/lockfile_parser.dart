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

import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/pub/lockfile.dart';
import 'package:inspectra/src/pub/lockfile_entry.dart';
import 'package:inspectra/src/util/yaml_plain.dart';
import 'package:yaml/yaml.dart';

/// Parses `pubspec.lock` files.
///
/// Malformed files produce an [InvalidInputException] with a precise message
/// instead of a type error, so that broken input always yields exit code
/// `65`.
final class LockfileParser {
  /// Creates a parser.
  const LockfileParser();

  /// Reads and parses the lockfile at [path].
  ///
  /// Returns the parsed lockfile.
  ///
  /// Throws an [InvalidInputException] when the file is missing or malformed.
  Lockfile parseFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw InvalidInputException('$path not found. Run "dart pub get" first.');
    }
    return parse(file.readAsStringSync(), path: path);
  }

  /// Parses lockfile [content] that was read from [path].
  ///
  /// Returns the parsed lockfile; a file without `packages` is valid and
  /// empty.
  ///
  /// Throws an [InvalidInputException] when [content] is malformed.
  Lockfile parse(String content, {required String path}) {
    final Object? document;
    try {
      document = toPlainValue(loadYaml(content));
    } on YamlException catch (error) {
      throw InvalidInputException('$path is not valid YAML: ${error.message}');
    }
    if (document == null) {
      return Lockfile(path: path, packages: const <LockfileEntry>[]);
    }
    if (document is! Map<String, Object?>) {
      throw InvalidInputException('$path is not a pubspec.lock file.');
    }
    final Object? packages = document['packages'];
    if (packages == null) {
      return Lockfile(path: path, packages: const <LockfileEntry>[]);
    }
    if (packages is! Map<String, Object?>) {
      throw InvalidInputException('"packages" in $path must be a mapping.');
    }
    final parsed = <LockfileEntry>[
      for (final entry in packages.entries)
        _parsePackage(entry.key, entry.value, path),
    ]..sort(_compare);
    return Lockfile(path: path, packages: parsed);
  }

  /// Orders direct dependencies first and then by name.
  ///
  /// Returns a negative, zero or positive comparison result.
  static int _compare(LockfileEntry a, LockfileEntry b) {
    if (a.isDirect != b.isDirect) {
      return a.isDirect ? -1 : 1;
    }
    return a.name.compareTo(b.name);
  }

  /// Parses the lockfile entry of package [name].
  ///
  /// Returns the locked package.
  ///
  /// Throws an [InvalidInputException] when the entry is not a mapping.
  LockfileEntry _parsePackage(String name, Object? value, String path) {
    if (value is! Map<String, Object?>) {
      throw InvalidInputException(
        'The entry of package "$name" in $path must be a mapping.',
      );
    }
    final Object? description = value['description'];
    final Object? url = description is Map<String, Object?>
        ? description['url']
        : null;
    final Object? sha256 = description is Map<String, Object?>
        ? description['sha256']
        : null;
    final String? hostedUrl = url is String ? url : null;
    final source = '${value['source'] ?? 'unknown'}';
    return LockfileEntry(
      name: name,
      version: '${value['version'] ?? ''}',
      source: source,
      dependency: '${value['dependency'] ?? ''}',
      hostedUrl: hostedUrl,
      gitUrl: source == 'git' ? hostedUrl : null,
      sha256: sha256 is String && sha256.isNotEmpty ? sha256 : null,
    );
  }
}
