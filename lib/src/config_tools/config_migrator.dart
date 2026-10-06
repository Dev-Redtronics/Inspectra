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

import 'package:inspectra/src/config/config_deprecation.dart';
import 'package:inspectra/src/config/config_layers.dart';
import 'package:inspectra/src/config/config_profiles.dart';
import 'package:inspectra/src/config/deprecated_option.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/config_tools/config_migration.dart';
import 'package:yaml/yaml.dart';

/// Replaces the old names of the renamed options [deprecations] in
/// [content], the text of the configuration file [label] whose
/// configuration lives at the keys [root] - none for `inspectra.yaml`,
/// `inspectra` for the section of `pubspec.yaml` - and in each of its
/// profiles. Only the keys change; values, comments and order stay.
///
/// Returns the migration.
///
/// Throws an [InspectraConfigException] for malformed YAML and for a
/// mapping that has the old and the new name of an option.
ConfigMigration migrateConfig(
  String content, {
  required String label,
  List<String> root = const <String>[],
  List<ConfigDeprecation> deprecations = configDeprecations,
}) {
  final Object? document = loadConfigYaml(content, label);
  final YamlMap? configuration = _mappingAt(document, root);
  final sections = <List<String>>[
    root,
    for (final Object? name
        in _mappingAt(configuration, const <String>[profilesKey])?.keys ??
            const <Object?>[])
      <String>[...root, profilesKey, '$name'],
  ];
  final edits = <(int, int, String)>[];
  final renamed = <DeprecatedOption>[];
  for (final base in sections) {
    for (final deprecation in deprecations) {
      final path = <String>[
        ...base,
        if (deprecation.section.isNotEmpty) ...deprecation.section.split('.'),
      ];
      final YamlMap? section = _mappingAt(document, path);
      final YamlScalar? key = _keyNode(section, deprecation.oldKey);
      if (key == null) {
        continue;
      }
      final String dotted = <String>[...path, deprecation.oldKey].join('.');
      if (section?.containsKey(deprecation.newKey) ?? false) {
        throw InspectraConfigException(
          dotted,
          'is the old name of ${deprecation.newKey}, which is set as well; '
          'remove one of them.',
          file: label,
        );
      }
      edits.add((
        key.span.start.offset,
        key.span.end.offset,
        deprecation.newKey,
      ));
      renamed.add(
        DeprecatedOption(
          deprecation: deprecation,
          path: dotted,
          line: key.span.start.line + 1,
        ),
      );
    }
  }
  edits.sort((a, b) => b.$1.compareTo(a.$1));
  var migrated = content;
  for (final (int start, int end, String text) in edits) {
    migrated = migrated.replaceRange(start, end, text);
  }
  renamed.sort((a, b) => (a.line ?? 0).compareTo(b.line ?? 0));
  return ConfigMigration(content: migrated, renamed: renamed);
}

/// Follows [path] through the nested mappings of [node].
///
/// Returns the mapping at [path], or `null` when there is none.
YamlMap? _mappingAt(Object? node, List<String> path) {
  var current = node;
  for (final key in path) {
    current = current is YamlMap ? current.nodes[key] : null;
  }
  return current is YamlMap ? current : null;
}

/// Finds the key [name] among the keys of [mapping].
///
/// Returns the key's node, which knows where it is written, or `null`.
YamlScalar? _keyNode(YamlMap? mapping, String name) {
  for (final Object? key in mapping?.nodes.keys ?? const <Object?>[]) {
    if (key is YamlScalar && key.value == name) {
      return key;
    }
  }
  return null;
}
