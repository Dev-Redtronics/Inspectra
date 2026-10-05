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

import 'package:inspectra/src/model/source_location.dart';
import 'package:yaml/yaml.dart';

/// Finds the lines of keys in a `pubspec.yaml` by its YAML structure.
///
/// Unlike a text search, a key is found in the section it belongs to: a
/// dependency named `sdk` under `dependencies` is not confused with
/// `environment.sdk` or `flutter: {sdk: flutter}`, and a package listed in
/// both dependency sections is found in the one asked for.
final class PubspecLocator {
  /// Creates a locator of the parsed document [_document] of the file at
  /// [path].
  const PubspecLocator._(this._document, this.path);

  /// Parses [content] of the file at [path].
  ///
  /// Returns a locator, which locates nothing but the file when [content]
  /// is no YAML mapping.
  factory PubspecLocator.parse(String content, String path) {
    try {
      final Object? document = loadYaml(content);
      return PubspecLocator._(document is YamlMap ? document : null, path);
    } on YamlException {
      return PubspecLocator._(null, path);
    }
  }

  /// The parsed document, or `null` when it is no mapping.
  final YamlMap? _document;

  /// The display path of the file.
  final String path;

  /// Returns the location of the top level [key], or of the file when it is
  /// absent.
  SourceLocation topLevel(String key) => _locate(_document, key);

  /// Returns the location of [key] within the top level [section], such as
  /// a dependency in `dependencies` or `sdk` in `environment`, or of the
  /// section, or of the file, when they are absent.
  SourceLocation entry(String section, String key) {
    final Object? node = _document?.nodes[section];
    if (node is! YamlMap) {
      return topLevel(section);
    }
    final SourceLocation found = _locate(node, key);
    return found.line == null ? topLevel(section) : found;
  }

  /// Returns the location of [key] in [map], or of the file when absent.
  SourceLocation _locate(YamlMap? map, String key) {
    if (map == null) {
      return SourceLocation(path);
    }
    for (final Object? node in map.nodes.keys) {
      if (node is YamlNode && node.value == key) {
        return SourceLocation(path, line: node.span.start.line + 1);
      }
    }
    return SourceLocation(path);
  }
}
