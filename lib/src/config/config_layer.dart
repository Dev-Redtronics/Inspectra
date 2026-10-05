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

import 'package:inspectra/src/config/config_layer_kind.dart';

/// One file of a layered configuration: the project's own configuration or
/// one of the bases it extends.
///
/// Layers are ordered from the lowest to the highest precedence; a value of
/// a higher layer replaces the value of a lower one.
final class ConfigLayer {
  /// Creates the layer [label]led for people, of the [kind], holding the
  /// parsed configuration mapping [node].
  ///
  /// [yamlPath] prefixes the paths of error messages, `inspectra` for the
  /// section of `pubspec.yaml`; [directory] is where relative paths in the
  /// file resolve, `null` for remote bases; [location] is the file that
  /// findings about the layer point at.
  const ConfigLayer({
    required this.label,
    required this.kind,
    required this.node,
    this.yamlPath = '',
    this.directory,
    this.location,
  });

  /// The name of the layer as written in `extends`, such as
  /// `package:acme_policy/inspectra.yaml`, or the project file's name.
  final String label;

  /// Where the layer comes from.
  final ConfigLayerKind kind;

  /// The parsed configuration mapping, or `null` when the file is empty.
  final Object? node;

  /// The dotted path of the configuration within its file.
  final String yamlPath;

  /// The absolute directory relative `extends` entries and the relative
  /// file options of a base resolve against, or `null` for remote bases.
  final String? directory;

  /// The file findings about this layer point at, or `null` to use the
  /// [label].
  final String? location;

  /// Whether the layer is a base rather than the project's configuration.
  bool get isBase => kind != ConfigLayerKind.project;

  /// Serializes the layer for the JSON report of `config show`.
  ///
  /// Returns the JSON object.
  Map<String, Object?> toJson() => <String, Object?>{
    'label': label,
    'kind': kind.id,
  };
}
