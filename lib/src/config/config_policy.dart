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

import 'package:inspectra/src/config/config_layer.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:yaml/yaml.dart';

/// The `policy:` section of a configuration file: options that the files
/// extending it, `INSPECTRA_*` variables and the command line must not
/// change, or may only make stricter.
final class ConfigPolicy {
  /// Creates the policy with the [locked] options and the [minimum] value
  /// of each option that may only be tightened.
  const ConfigPolicy({
    this.locked = const <String>[],
    this.minimum = const <String, Object?>{},
  });

  /// Reads the policy of [layer].
  ///
  /// Returns the policy, which is empty when the layer has none.
  ///
  /// Throws an [InspectraConfigException] when it is malformed.
  factory ConfigPolicy.of(ConfigLayer layer) {
    final Object? node = layer.node;
    final Object? raw = _plain(node is Map ? node['policy'] : null);
    final String path = pathIn(layer, 'policy');
    final String? file = layer.isBase ? layer.label : null;
    if (raw == null) {
      return const ConfigPolicy();
    }
    if (raw is! Map) {
      throw InspectraConfigException(
        path,
        'expected a mapping with locked and minimum.',
        file: file,
      );
    }
    for (final Object? key in raw.keys) {
      if (key != 'locked' && key != 'minimum') {
        throw InspectraConfigException(
          '$path.$key',
          'unknown option. Known options here: locked, minimum.',
          file: file,
        );
      }
    }
    final Object? locked = _plain(raw['locked']);
    final Object? minimum = _plain(raw['minimum']);
    final bool lockedValid =
        locked == null ||
        locked is List && locked.every((key) => _plain(key) is String);
    if (!lockedValid) {
      throw InspectraConfigException(
        '$path.locked',
        'expected a list of dotted option names.',
        file: file,
      );
    }
    if (minimum != null && minimum is! Map) {
      throw InspectraConfigException(
        '$path.minimum',
        'expected a mapping from dotted option names to values.',
        file: file,
      );
    }
    return ConfigPolicy(
      locked: <String>[
        if (locked is List)
          for (final Object? key in locked) '${_plain(key)}',
      ],
      minimum: <String, Object?>{
        if (minimum is Map)
          for (final MapEntry<Object?, Object?> entry in minimum.entries)
            '${_plain(entry.key)}': _plain(entry.value),
      },
    );
  }

  /// The options that must keep the value of the declaring file and its
  /// bases.
  final List<String> locked;

  /// The weakest allowed value of each option that may only be tightened.
  final Map<String, Object?> minimum;

  /// Whether the policy restricts nothing.
  bool get isEmpty => locked.isEmpty && minimum.isEmpty;

  /// Returns the dotted path of [key] in [layer], for error messages.
  static String pathIn(ConfigLayer layer, String key) =>
      layer.yamlPath.isEmpty ? key : '${layer.yamlPath}.$key';

  /// Returns [value] without its YAML wrapper.
  static Object? _plain(Object? value) =>
      value is YamlScalar ? value.value : value;
}
