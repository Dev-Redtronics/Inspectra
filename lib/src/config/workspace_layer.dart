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

import 'package:glob/glob.dart';
import 'package:inspectra/src/config/config_suggestion.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/config/yaml_reader.dart';

/// A layer of the architecture of a workspace, an entry of
/// `workspace_policy.layers`: the packages in it and what they may depend
/// on.
final class WorkspaceLayer {
  /// Creates the layer [name] of the packages whose directories, relative
  /// to the workspace root, match one of [packages]; [mayDependOn] lists
  /// the other layers its packages may depend on, every layer when `null`;
  /// with [isolated] its packages may not depend on each other; and
  /// [forbiddenDependencies] are packages none of them may depend on.
  const WorkspaceLayer({
    required this.name,
    required this.packages,
    this.mayDependOn,
    this.isolated = false,
    this.forbiddenDependencies = const <String>[],
  });

  /// Parses one [entry] of the list at [path].
  ///
  /// Returns the layer.
  ///
  /// Throws an [InspectraConfigException] for a malformed entry.
  factory WorkspaceLayer._fromEntry(Object? entry, String path) {
    if (entry is! Map) {
      throw InspectraConfigException(
        path,
        'expected a mapping with name and packages.',
      );
    }
    const allowed = <String>{
      'name',
      'packages',
      'may_depend_on',
      'isolated',
      'forbidden_dependencies',
    };
    final Iterable<Object?> unknown = entry.keys.where(
      (key) => !allowed.contains('$key'),
    );
    if (unknown.isNotEmpty) {
      throw InspectraConfigException(
        '$path.${unknown.first}',
        'unknown option.${didYouMean('${unknown.first}', allowed)} Known '
            'options here: ${allowed.join(', ')}.',
      );
    }
    final Object? name = entry['name'];
    if (name is! String || name.trim().isEmpty) {
      throw InspectraConfigException('$path.name', 'a layer name is required.');
    }
    final List<String>? packages = _names(entry['packages'], '$path.packages');
    if (packages == null || packages.isEmpty) {
      throw InspectraConfigException(
        '$path.packages',
        'expected a list of directory globs, such as [features/*].',
      );
    }
    final Object? isolated = entry['isolated'];
    if (isolated != null && isolated is! bool) {
      throw InspectraConfigException(
        '$path.isolated',
        'expected true or false.',
      );
    }
    return WorkspaceLayer(
      name: name.trim(),
      packages: packages,
      mayDependOn: _names(entry['may_depend_on'], '$path.may_depend_on'),
      isolated: isolated == true,
      forbiddenDependencies:
          _names(
            entry['forbidden_dependencies'],
            '$path.forbidden_dependencies',
          ) ??
          const <String>[],
    );
  }

  /// Reads the `layers` list of the `workspace_policy` section in [yaml];
  /// every layer of the configuration adds its entries.
  ///
  /// Returns the layers, empty when the list is absent.
  ///
  /// Throws an [InspectraConfigException] for malformed entries, unknown
  /// keys, and two layers of the same name.
  static List<WorkspaceLayer> listFromYaml(YamlReader yaml) {
    final layers = <WorkspaceLayer>[];
    for (final (Object? raw, String path, String? file)
        in yaml.structuredLayers('layers', fallback: const <Object?>[])) {
      if (raw == null) {
        continue;
      }
      if (raw is! List) {
        throw InspectraConfigException(
          path,
          'expected a list of layers with name and packages.',
          file: file,
        );
      }
      for (var index = 0; index < raw.length; index++) {
        final at = '$path[$index]';
        final WorkspaceLayer layer;
        try {
          layer = WorkspaceLayer._fromEntry(raw[index], at);
        } on InspectraConfigException catch (error) {
          throw InspectraConfigException(
            error.path,
            error.message,
            file: file ?? error.file,
          );
        }
        if (layers.any((known) => known.name == layer.name)) {
          throw InspectraConfigException(
            '$at.name',
            'the layer ${layer.name} is defined twice.',
            file: file,
          );
        }
        layers.add(layer);
      }
    }
    final names = <String>{for (final layer in layers) layer.name};
    for (final layer in layers) {
      for (final String other in layer.mayDependOn ?? const <String>[]) {
        if (!names.contains(other)) {
          throw InspectraConfigException(
            'workspace_policy.layers',
            'the layer ${layer.name} may depend on $other, which is no '
                'layer.${didYouMean(other, names)}',
          );
        }
      }
    }
    return List<WorkspaceLayer>.unmodifiable(layers);
  }

  /// The name other layers refer to.
  final String name;

  /// Globs of the package directories, relative to the workspace root.
  final List<String> packages;

  /// The other layers this layer's packages may depend on, or `null` for
  /// every layer.
  final List<String>? mayDependOn;

  /// Whether the packages of this layer may not depend on each other.
  final bool isolated;

  /// Packages, internal or external, no package of this layer may depend
  /// on, such as `flutter` for a pure Dart domain layer.
  final List<String> forbiddenDependencies;

  /// Whether the package in [directory], relative to the workspace root
  /// with `/` separators, belongs to this layer.
  ///
  /// Returns `true` when one of [packages] matches.
  bool contains(String directory) =>
      packages.any((pattern) => Glob(pattern).matches(directory));

  /// Reads the list of names at [path].
  ///
  /// Returns the names, or `null` when [value] is absent.
  ///
  /// Throws an [InspectraConfigException] when it is no list of texts.
  static List<String>? _names(Object? value, String path) {
    if (value == null) {
      return null;
    }
    final bool valid =
        value is List && value.every((item) => item is String && item != '');
    if (!valid) {
      throw InspectraConfigException(path, 'expected a list of names.');
    }
    return List<String>.unmodifiable(value.cast<String>());
  }
}
