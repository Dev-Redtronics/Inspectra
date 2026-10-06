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
import 'package:inspectra/src/config/yaml_reader.dart';

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

/// The schema of one entry of `dependency_policy.overrides.allowed`.
const _overrideEntry = <String, Object?>{
  'type': 'object',
  'required': <String>['name', 'reason'],
  'additionalProperties': false,
  'properties': <String, Object?>{
    'name': <String, Object?>{
      'type': 'string',
      'description': 'The overridden package.',
    },
    'reason': <String, Object?>{
      'type': 'string',
      'description': 'Why the override is needed.',
    },
    'expires': <String, Object?>{
      'type': 'string',
      'description': 'The last day the justification holds, YYYY-MM-DD.',
      'pattern': r'^\d{4}-\d{2}-\d{2}',
    },
  },
};

/// The schema of one entry of `workspace_policy.layers`.
const _layerEntry = <String, Object?>{
  'type': 'object',
  'required': <String>['name', 'packages'],
  'additionalProperties': false,
  'properties': <String, Object?>{
    'name': <String, Object?>{
      'type': 'string',
      'description': 'The name other layers refer to.',
    },
    'packages': <String, Object?>{
      'type': 'array',
      'description':
          'Globs of the package directories, relative to the workspace root.',
      'items': <String, Object?>{'type': 'string'},
    },
    'may_depend_on': <String, Object?>{
      'type': 'array',
      'description':
          'The other layers its packages may depend on; every layer when '
          'absent.',
      'items': <String, Object?>{'type': 'string'},
    },
    'isolated': <String, Object?>{
      'type': 'boolean',
      'description': 'Whether its packages may not depend on each other.',
    },
    'forbidden_dependencies': <String, Object?>{
      'type': 'array',
      'description': 'Packages none of its packages may depend on.',
      'items': <String, Object?>{'type': 'string'},
    },
  },
};

/// The schema of one base named by `extends`: a path relative to the file,
/// a `package:` URI, or an `https` URL pinned by its SHA-256.
const _baseEntry = <String, Object?>{
  'oneOf': <Object?>[
    <String, Object?>{
      'type': 'string',
      'description': 'A path relative to this file, or package:<name>/<path>.',
      'minLength': 1,
    },
    <String, Object?>{
      'type': 'object',
      'required': <String>['url', 'sha256'],
      'additionalProperties': false,
      'properties': <String, Object?>{
        'url': <String, Object?>{
          'type': 'string',
          'description': 'The https URL of the base.',
          'pattern': '^https://',
        },
        'sha256': <String, Object?>{
          'type': 'string',
          'description': 'The SHA-256 the content of the base must have.',
          'pattern': r'^[0-9a-fA-F]{64}$',
        },
      },
    },
  ],
};

/// The schema of `extends`, `profiles` and `policy`, which the
/// configuration reads before it is parsed.
const _layerProperties = <String, Object?>{
  'extends': <String, Object?>{
    'description':
        'The configurations this one builds on, from the lowest to the '
        'highest precedence.',
    'oneOf': <Object?>[
      _baseEntry,
      <String, Object?>{'type': 'array', 'items': _baseEntry},
    ],
  },
  'profiles': <String, Object?>{
    'type': 'object',
    'description':
        'Named partial configurations that --profile or INSPECTRA_PROFILE '
        'applies on top of this file; they cannot set extends, policy or '
        'profiles.',
    'additionalProperties': <String, Object?>{r'$ref': '#'},
  },
  'policy': <String, Object?>{
    'type': 'object',
    'description':
        'Options that the files extending this one, environment variables '
        'and the command line must not change, or may only tighten, and the '
        'severities no ignore may hide.',
    'additionalProperties': false,
    'properties': <String, Object?>{
      'forbid_ignore_of': <String, Object?>{
        'type': 'array',
        'description':
            'Severities of findings that no ignore rule, --ignore flag or '
            'baseline may suppress.',
        'items': <String, Object?>{
          'enum': <String>[
            'critical',
            'high',
            'medium',
            'low',
            'unknown',
            'CRITICAL',
            'HIGH',
            'MEDIUM',
            'LOW',
            'UNKNOWN',
          ],
        },
      },
      'locked': <String, Object?>{
        'type': 'array',
        'description': 'Dotted options that must keep their value.',
        'items': <String, Object?>{'type': 'string'},
      },
      'minimum': <String, Object?>{
        'type': 'object',
        'description': 'The weakest allowed value of dotted options.',
        'additionalProperties': <String, Object?>{
          'type': <String>['boolean', 'number', 'string'],
        },
      },
    },
  },
};

/// The schema of the entries of each structured option.
const _structuredEntries = <String, Map<String, Object?>>{
  'ignore': _ignoreEntry,
  'dependency_policy.denied': _deniedEntry,
  'dependency_policy.overrides.allowed': _overrideEntry,
  'workspace_policy.layers': _layerEntry,
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
    'properties': <String, Object?>{..._layerProperties},
  };
  for (final ConfigEntry entry in recorder.entries) {
    final List<String> parts = entry.key.split('.');
    final Map<String, Object?> parent = _objectAt(
      root,
      parts.take(parts.length - 1).toList(),
    );
    final properties = parent['properties']! as Map<String, Object?>;
    final Map<String, Object?> schema = _schemaOf(entry);
    properties[parts.last] = schema;
    final bool isList =
        entry.kind == ConfigKind.strings || entry.kind == ConfigKind.enumList;
    if (isList) {
      properties['${parts.last}${YamlReader.appendSuffix}'] = <String, Object?>{
        for (final MapEntry<String, Object?> part in schema.entries)
          if (part.key != 'default') part.key: part.value,
        'description':
            'Adds to the list of the lower layers instead of replacing it.',
      };
    }
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
