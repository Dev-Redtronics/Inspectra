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
import 'package:inspectra/src/pub/dependency_kind.dart';
import 'package:inspectra/src/pub/dependency_spec.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/util/yaml_plain.dart';
import 'package:yaml/yaml.dart';

/// Parses `pubspec.yaml` files into [Pubspec] values.
///
/// All dependency notations accepted by pub are understood, including the
/// Git shorthand `git: <url>` that crashed earlier tools.
final class PubspecParser {
  /// Creates a parser.
  const PubspecParser();

  /// Reads and parses the pubspec at [path].
  ///
  /// Returns the parsed pubspec.
  ///
  /// Throws an [InvalidInputException] when the file is missing or malformed.
  Pubspec parseFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw InvalidInputException('$path not found.');
    }
    return parse(file.readAsStringSync(), path: path);
  }

  /// Parses pubspec [content] that was read from [path].
  ///
  /// Returns the parsed pubspec.
  ///
  /// Throws an [InvalidInputException] when [content] is malformed.
  Pubspec parse(String content, {required String path}) {
    final Object? document;
    try {
      document = toPlainValue(loadYaml(content));
    } on YamlException catch (error) {
      throw InvalidInputException('$path is not valid YAML: ${error.message}');
    }
    if (document == null) {
      return Pubspec(path: path);
    }
    if (document is! Map<String, Object?>) {
      throw InvalidInputException('$path is not a pubspec.yaml file.');
    }
    final Object? environment = document['environment'];
    final Map<String, Object?> environmentMap =
        environment is Map<String, Object?>
        ? environment
        : const <String, Object?>{};
    return Pubspec(
      path: path,
      name: _stringOrNull(document['name']),
      version: _stringOrNull(document['version']),
      repository: _stringOrNull(document['repository']),
      dependencies: _section(document, 'dependencies', path),
      devDependencies: _section(document, 'dev_dependencies', path),
      dependencyOverrides: _section(document, 'dependency_overrides', path),
      sdkConstraint: _stringOrNull(environmentMap['sdk']),
      flutterConstraint: _stringOrNull(environmentMap['flutter']),
    );
  }

  /// Parses the dependency section [key] of [document].
  ///
  /// Returns the declarations keyed by package name.
  ///
  /// Throws an [InvalidInputException] when the section is not a mapping.
  Map<String, DependencySpec> _section(
    Map<String, Object?> document,
    String key,
    String path,
  ) {
    final Object? section = document[key];
    if (section == null) {
      return const <String, DependencySpec>{};
    }
    if (section is! Map<String, Object?>) {
      throw InvalidInputException('"$key" in $path must be a mapping.');
    }
    return <String, DependencySpec>{
      for (final entry in section.entries)
        entry.key: _dependency(entry.key, entry.value, path),
    };
  }

  /// Parses the declaration [value] of dependency [name].
  ///
  /// Returns the declaration.
  ///
  /// Throws an [InvalidInputException] for unsupported notations.
  DependencySpec _dependency(String name, Object? value, String path) {
    if (value == null) {
      return const DependencySpec(kind: DependencyKind.hosted);
    }
    if (value is! Map<String, Object?>) {
      return DependencySpec(kind: DependencyKind.hosted, constraint: '$value');
    }
    final String? constraint = _stringOrNull(value['version']);
    if (value.containsKey('git')) {
      return _gitDependency(value['git'], constraint);
    }
    if (value.containsKey('path')) {
      return DependencySpec(
        kind: DependencyKind.path,
        path: _stringOrNull(value['path']),
      );
    }
    if (value.containsKey('sdk')) {
      return DependencySpec(
        kind: DependencyKind.sdk,
        sdk: _stringOrNull(value['sdk']),
        constraint: constraint,
      );
    }
    if (value.containsKey('hosted') || value.containsKey('version')) {
      return DependencySpec(
        kind: DependencyKind.hosted,
        constraint: constraint,
        hostedUrl: _hostedUrl(value['hosted']),
      );
    }
    throw InvalidInputException(
      'The dependency "$name" in $path uses an unsupported notation.',
    );
  }

  /// Parses a Git dependency, accepting both `git: <url>` and the long form
  /// with `url`, `ref` and `path`.
  ///
  /// Returns the declaration.
  DependencySpec _gitDependency(Object? git, String? constraint) {
    if (git is Map<String, Object?>) {
      return DependencySpec(
        kind: DependencyKind.git,
        gitUrl: _stringOrNull(git['url']),
        gitRef: _stringOrNull(git['ref']),
        constraint: constraint,
      );
    }
    return DependencySpec(
      kind: DependencyKind.git,
      gitUrl: _stringOrNull(git),
      constraint: constraint,
    );
  }

  /// Extracts the registry URL of a `hosted:` value, which is either the URL
  /// itself or a mapping with `url`.
  ///
  /// Returns the URL, or `null` for pub.dev.
  String? _hostedUrl(Object? hosted) {
    if (hosted is Map<String, Object?>) {
      return _stringOrNull(hosted['url']);
    }
    return _stringOrNull(hosted);
  }

  /// Returns [value] as a trimmed non-blank string, or `null`.
  String? _stringOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    final String text = '$value'.trim();
    return text.isEmpty ? null : text;
  }
}
