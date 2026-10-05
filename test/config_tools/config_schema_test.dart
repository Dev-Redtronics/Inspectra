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

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/config_tools/config_schema.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Tests the JSON Schema of the configuration and guards the committed
/// schema and the example configuration against drift.
void main() {
  /// Returns the property schema at the dotted [path] of [schema].
  Map<String, Object?> at(Map<String, Object?> schema, String path) {
    var node = schema;
    for (final String part in path.split('.')) {
      final properties = node['properties']! as Map<String, Object?>;
      node = properties[part]! as Map<String, Object?>;
    }
    return node;
  }

  final Map<String, Object?> schema = buildConfigSchema();

  test('describes every kind of option with its default', () {
    expect(schema[r'$schema'], 'http://json-schema.org/draft-07/schema#');
    expect(schema['additionalProperties'], isFalse);
    expect(at(schema, 'format.enabled'), <String, Object?>{
      'type': 'boolean',
      'default': false,
    });
    expect(at(schema, 'network.max_attempts'), <String, Object?>{
      'type': 'integer',
      'minimum': 1,
      'maximum': 100,
      'default': 3,
    });
    expect(at(schema, 'trust.min_points_ratio')['type'], 'number');
    expect(at(schema, 'trivy.timeout')['default'], '10m');
    expect(at(schema, 'trivy.mode')['enum'], containsAll(<String>['auto']));
    expect(at(schema, 'fail_on')['enum'], contains('HIGH'));
    expect(at(schema, 'fail_on').containsKey('default'), isFalse);
    final Map<String, Object?> severity = at(schema, 'trivy.secret.severity');
    expect(severity['minItems'], 1);
    expect((severity['items']! as Map)['enum'], contains('critical'));
    expect(at(schema, 'api.output')['default'], 'api/<package>.api');
    final Map<String, Object?> ignore = at(schema, 'ignore');
    expect(ignore['type'], 'array');
    expect((ignore['items']! as Map)['required'], <String>['id', 'reason']);
  });

  test('lets style rules and changelog types be named freely', () {
    expect(at(schema, 'style.rules')['additionalProperties'], <String, Object?>{
      'type': 'boolean',
    });
    final Map<String, Object?> types = at(schema, 'changelog.types');
    expect((types['additionalProperties']! as Map)['enum'], contains('added'));
    expect(at(schema, 'changelog.types.feat')['default'], 'added');
    expect(at(schema, 'trivy')['additionalProperties'], isFalse);
  });

  test('inspectra.schema.json is the generated schema', () {
    final String committed = File('inspectra.schema.json').readAsStringSync();
    expect(
      committed.replaceAll('\r\n', '\n'),
      renderConfigSchema(),
      reason:
          'Regenerate it with: dart run inspectra config schema -o '
          'inspectra.schema.json',
    );
  });

  test('inspectra.example.yaml lists every option with its default', () {
    const derivedDefaults = <String>{'api.output', 'network.pub_hosted_url'};
    final example =
        loadYaml(File('inspectra.example.yaml').readAsStringSync()) as YamlMap;
    final withoutIgnore = <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in example.entries)
        if (entry.key != 'ignore') '${entry.key}': entry.value,
    };
    final recorder = ConfigRecorder();
    InspectraConfig.parse(
      withoutIgnore,
      packageName: 'demo',
      recorder: recorder,
    );
    final differing = <String>[
      for (final ConfigEntry entry in recorder.entries)
        if (entry.origin == ConfigOrigin.file &&
            '${entry.value}' != '${entry.defaultValue}')
          '${entry.key}: ${entry.value} (default ${entry.defaultValue})',
    ];
    expect(differing, isEmpty);
    final keys = <String>{
      for (final ConfigEntry entry in recorder.entries) entry.key,
    };
    final undocumented = <String>[
      for (final ConfigEntry entry in recorder.entries)
        if (entry.origin == ConfigOrigin.defaults &&
            entry.value != null &&
            !entry.key.startsWith('style.rules.') &&
            !entry.key.startsWith('changelog.types.') &&
            entry.key != 'ignore' &&
            !derivedDefaults.contains(entry.key))
          entry.key,
    ];
    expect(keys, isNotEmpty);
    expect(undocumented, isEmpty);
  });
}
