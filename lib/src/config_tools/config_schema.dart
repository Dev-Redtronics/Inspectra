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

import 'package:inspectra/src/config/inspectra_config.dart';

/// Where the published schema lives, its `$id`.
const configSchemaUrl =
    'https://raw.githubusercontent.com/davils-com/Inspectra/main/'
    'inspectra.schema.json';

/// The package name the schema shows in defaults derived from it.
const _packagePlaceholder = '<package>';

/// The sections whose keys are names chosen by the user, with the schema of
/// each value: style rule switches and changelog types.
final _openSections = <String, Map<String, Object?>>{
  'style.rules': <String, Object?>{'type': 'boolean'},
  'changelog.types': <String, Object?>{
    'enum': _bothCases(ChangelogSection.byId.keys.toList()),
  },
};

/// The schema of one entry of the `ignore` list.
const _ignoreEntry = <String, Object?>{
  'type': 'object',
  'required': <String>['id', 'reason'],
  'additionalProperties': false,
  'properties': <String, Object?>{
    'id': <String, Object?>{
      'type': 'string',
      'description': 'The rule id, advisory id or alias to suppress.',
    },
    'reason': <String, Object?>{
      'type': 'string',
      'description': 'Why the finding is acceptable.',
    },
    'package': <String, Object?>{
      'type': 'string',
      'description': 'Restricts the entry to findings of this package.',
    },
    'expires': <String, Object?>{
      'type': 'string',
      'description': 'The last day the entry applies, YYYY-MM-DD.',
      'pattern': r'^\d{4}-\d{2}-\d{2}',
    },
  },
};

/// The schema of one entry of `dependency_policy.denied`.
const _deniedEntry = <String, Object?>{
  'type': 'object',
  'required': <String>['name', 'reason'],
  'additionalProperties': false,
  'properties': <String, Object?>{
    'name': <String, Object?>{
      'type': 'string',
      'description': 'The forbidden package.',
    },
    'reason': <String, Object?>{
      'type': 'string',
      'description': 'Why the package is forbidden.',
    },
    'replacement': <String, Object?>{
      'type': 'string',
      'description': 'The package to use instead.',
    },
  },
};

/// The schema of the entries of each structured option.
const _structuredEntries = <String, Map<String, Object?>>{
  'ignore': _ignoreEntry,
  'dependency_policy.denied': _deniedEntry,
};

/// Builds the JSON Schema (draft-07) of `inspectra.yaml` from the options
/// the configuration actually reads, so that it cannot drift from the
/// code.
///
/// Returns the schema document.
Map<String, Object?> buildConfigSchema() {
  final recorder = ConfigRecorder();
  InspectraConfig.parse(
    null,
    packageName: _packagePlaceholder,
    recorder: recorder,
  );
  final root = <String, Object?>{
    r'$schema': 'http://json-schema.org/draft-07/schema#',
    r'$id': configSchemaUrl,
    'title': 'Inspectra configuration',
    'description':
        'The keys of inspectra.yaml, or of the inspectra: section of '
        'pubspec.yaml.',
    'type': 'object',
    'additionalProperties': false,
    'properties': <String, Object?>{},
  };
  for (final ConfigEntry entry in recorder.entries) {
    final List<String> parts = entry.key.split('.');
    final Map<String, Object?> parent = _objectAt(
      root,
      parts.take(parts.length - 1).toList(),
    );
    final properties = parent['properties']! as Map<String, Object?>;
    properties[parts.last] = _schemaOf(entry);
  }
  return root;
}

/// Renders the schema as indented JSON with a final line break.
///
/// Returns the text of `inspectra.schema.json`.
String renderConfigSchema() =>
    '${const JsonEncoder.withIndent('  ').convert(buildConfigSchema())}\n';

/// Finds the object schema at [path] below [root], creating the sections
/// on the way.
///
/// Returns the object schema.
Map<String, Object?> _objectAt(Map<String, Object?> root, List<String> path) {
  var node = root;
  for (var index = 0; index < path.length; index++) {
    final properties = node['properties']! as Map<String, Object?>;
    final String dotted = path.take(index + 1).join('.');
    final Object? existing = properties[path[index]];
    final Map<String, Object?> child = existing is Map<String, Object?>
        ? existing
        : <String, Object?>{
            'type': 'object',
            'additionalProperties': _openSections[dotted] ?? false,
            'properties': <String, Object?>{},
          };
    properties[path[index]] = child;
    node = child;
  }
  return node;
}

/// Describes the option [entry].
///
/// Returns its schema, with its default.
Map<String, Object?> _schemaOf(ConfigEntry entry) {
  final Object? defaultValue = entry.defaultValue;
  final List<String> options = entry.options ?? const <String>[];
  final Map<String, Object?> type = switch (entry.kind) {
    ConfigKind.boolean => <String, Object?>{'type': 'boolean'},
    ConfigKind.string => <String, Object?>{
      'type': <String>['string', 'number'],
    },
    ConfigKind.integer => <String, Object?>{
      'type': 'integer',
      'minimum': ?entry.minimum,
      'maximum': ?entry.maximum,
    },
    ConfigKind.number => <String, Object?>{
      'type': 'number',
      'minimum': ?entry.minimum,
      'maximum': ?entry.maximum,
    },
    ConfigKind.duration => <String, Object?>{
      'type': <String>['string', 'integer'],
      'pattern': r'^\d+\s*(ms|s|m|h)?$',
    },
    ConfigKind.strings => <String, Object?>{
      'type': 'array',
      'items': <String, Object?>{
        'type': <String>['string', 'number'],
      },
    },
    ConfigKind.enumList => <String, Object?>{
      'type': 'array',
      'minItems': entry.minimum ?? 1,
      'items': <String, Object?>{'enum': _bothCases(options)},
    },
    ConfigKind.choice => <String, Object?>{'enum': _bothCases(options)},
    ConfigKind.structured => <String, Object?>{
      'type': 'array',
      'items':
          _structuredEntries[entry.key] ??
          const <String, Object?>{'type': 'object'},
    },
  };
  return <String, Object?>{...type, 'default': ?defaultValue};
}

/// Returns [options] in their own, lower and upper case, as the
/// configuration reads names regardless of case.
List<String> _bothCases(List<String> options) => <String>{
  ...options,
  ...options.map((option) => option.toLowerCase()),
  ...options.map((option) => option.toUpperCase()),
}.toList();
