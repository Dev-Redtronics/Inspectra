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

import 'package:inspectra/src/config/config_suggestion.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/config/yaml_reader.dart';

/// A package the dependency policy forbids, an entry of
/// `dependency_policy.denied`.
final class DeniedPackage {
  /// Creates the rule that forbids [name] because of [reason], optionally
  /// naming its [replacement].
  const DeniedPackage({
    required this.name,
    required this.reason,
    this.replacement,
  });

  /// Parses one [entry] of the list at [path].
  ///
  /// Returns the rule.
  ///
  /// Throws an [InspectraConfigException] for a malformed entry.
  factory DeniedPackage._fromEntry(Object? entry, String path) {
    if (entry is! Map) {
      throw InspectraConfigException(
        path,
        'expected a mapping with name and reason.',
      );
    }
    const allowed = <String>{'name', 'reason', 'replacement'};
    final Iterable<Object?> unknown = entry.keys.where(
      (key) => !allowed.contains('$key'),
    );
    if (unknown.isNotEmpty) {
      throw InspectraConfigException(
        '$path.${unknown.first}',
        'unknown option.${didYouMean('${unknown.first}', allowed)} Known '
            'options here: name, reason, replacement.',
      );
    }
    final String? name = _text(entry['name']);
    final String? reason = _text(entry['reason']);
    if (name == null) {
      throw InspectraConfigException(
        '$path.name',
        'a package name is required.',
      );
    }
    if (reason == null) {
      throw InspectraConfigException(
        '$path.reason',
        'a reason is required, so that everyone knows why the package is '
            'denied.',
      );
    }
    return DeniedPackage(
      name: name,
      reason: reason,
      replacement: _text(entry['replacement']),
    );
  }

  /// Reads the `denied` list of the `dependency_policy` section in [yaml];
  /// only the configuration file can express it.
  ///
  /// Returns the rules, empty when the list is absent.
  ///
  /// Throws an [InspectraConfigException] for malformed entries, entries
  /// without `name` or `reason`, and unknown keys.
  static List<DeniedPackage> listFromYaml(YamlReader yaml) {
    final rules = <DeniedPackage>[];
    for (final (Object? raw, String path, String? file)
        in yaml.structuredLayers('denied', fallback: const <Object?>[])) {
      if (raw == null) {
        continue;
      }
      if (raw is! List) {
        throw InspectraConfigException(
          path,
          'expected a list of entries with name and reason.',
          file: file,
        );
      }
      for (var index = 0; index < raw.length; index++) {
        try {
          rules.add(DeniedPackage._fromEntry(raw[index], '$path[$index]'));
        } on InspectraConfigException catch (error) {
          throw InspectraConfigException(
            error.path,
            error.message,
            file: file ?? error.file,
          );
        }
      }
    }
    return List<DeniedPackage>.unmodifiable(rules);
  }

  /// The forbidden package.
  final String name;

  /// Why the package is forbidden.
  final String reason;

  /// The package to use instead, if any.
  final String? replacement;

  /// Returns [value] as trimmed text, or `null` when absent or blank.
  static String? _text(Object? value) {
    if (value == null) {
      return null;
    }
    final String text = '$value'.trim();
    return text.isEmpty ? null : text;
  }
}
