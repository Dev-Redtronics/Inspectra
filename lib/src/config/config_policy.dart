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
import 'package:inspectra/src/model/severity.dart';
import 'package:yaml/yaml.dart';

/// The `policy:` section of a configuration file: options that the files
/// extending it, `INSPECTRA_*` variables and the command line must not
/// change, or may only make stricter, and the severities no ignore rule may
/// hide.
final class ConfigPolicy {
  /// Creates the policy with the [locked] options, the [minimum] value of
  /// each option that may only be tightened and the severities of findings
  /// that no ignore rule may suppress, [forbidIgnoreOf].
  const ConfigPolicy({
    this.locked = const <String>[],
    this.minimum = const <String, Object?>{},
    this.forbidIgnoreOf = const <Severity>[],
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
        'expected a mapping with locked, minimum and forbid_ignore_of.',
        file: file,
      );
    }
    for (final Object? key in raw.keys) {
      if (!_keys.contains(key)) {
        throw InspectraConfigException(
          '$path.$key',
          'unknown option. Known options here: ${_keys.join(', ')}.',
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
      forbidIgnoreOf: _severities(
        _plain(raw['forbid_ignore_of']),
        '$path.forbid_ignore_of',
        file,
      ),
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

  /// The severities of findings that neither an ignore rule, an `--ignore`
  /// flag nor the baseline may suppress.
  final List<Severity> forbidIgnoreOf;

  /// Whether the policy restricts nothing.
  bool get isEmpty =>
      locked.isEmpty && minimum.isEmpty && forbidIgnoreOf.isEmpty;

  /// The keys a policy may have.
  static const _keys = <String>['forbid_ignore_of', 'locked', 'minimum'];

  /// Returns the dotted path of [key] in [layer], for error messages.
  static String pathIn(ConfigLayer layer, String key) =>
      layer.yamlPath.isEmpty ? key : '${layer.yamlPath}.$key';

  /// Reads the severity names of [value], the list at [path] of [file],
  /// in any case.
  ///
  /// Returns the severities, none when [value] is `null`.
  ///
  /// Throws an [InspectraConfigException] when [value] is no list of
  /// severity names.
  static List<Severity> _severities(Object? value, String path, String? file) {
    if (value == null) {
      return const <Severity>[];
    }
    final names = <String>[
      for (final severity in Severity.values) severity.name,
    ];
    if (value is! List) {
      throw InspectraConfigException(
        path,
        'expected a list of severities: ${names.join(', ')}.',
        file: file,
      );
    }
    final severities = <Severity>[];
    for (final Object? item in value) {
      final String name = '${_plain(item)}'.toLowerCase();
      final Iterable<Severity> matches = Severity.values.where(
        (severity) => severity.name == name,
      );
      if (matches.isEmpty) {
        throw InspectraConfigException(
          path,
          '"${_plain(item)}" is no severity; expected one of '
          '${names.join(', ')}.',
          file: file,
        );
      }
      severities.add(matches.first);
    }
    return severities;
  }

  /// Returns [value] without its YAML wrapper.
  static Object? _plain(Object? value) =>
      value is YamlScalar ? value.value : value;
}
