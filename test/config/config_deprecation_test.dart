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

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/config/yaml_reader.dart';
import 'package:inspectra/src/config_tools/config_lint.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Tests reading renamed options under their old names.
void main() {
  const renames = <ConfigDeprecation>[
    ConfigDeprecation(
      oldPath: 'trivy.secrets',
      newPath: 'trivy.secret',
      since: '1.1.0',
    ),
    ConfigDeprecation(
      oldPath: 'fail_level',
      newPath: 'fail_on',
      since: '1.1.0',
      note: 'It names the threshold like the flag.',
    ),
  ];

  /// Reads `fail_on` and `trivy.secret.enabled` of [yaml] with the test
  /// renames, recording into [recorder].
  ///
  /// Returns the reader of the root.
  YamlReader read(String yaml, {ConfigRecorder? recorder}) {
    final reader = YamlReader(
      loadYaml(yaml),
      '',
      recorder: recorder,
      deprecations: renames,
    )..optionalString('fail_on');
    final YamlReader trivy = reader.section('trivy');
    trivy.section('secret')
      ..optionalBoolean('enabled')
      ..ensureFullyRead();
    trivy.ensureFullyRead();
    reader.ensureFullyRead();
    return reader;
  }

  test('reads old names under the new ones and remembers each use', () {
    final recorder = ConfigRecorder();
    final YamlReader reader = read(
      'fail_level: high\ntrivy:\n  secrets:\n    enabled: true\n',
      recorder: recorder,
    );
    expect(recorder['fail_on']?.value, 'high');
    expect(recorder['fail_on']?.line, 1);
    expect(recorder['trivy.secret.enabled']?.value, isTrue);
    expect(reader.deprecatedOptions.map((option) => option.path), <String>[
      'fail_level',
      'trivy.secrets',
    ]);
    expect(reader.deprecatedOptions.last.line, 3);
    expect(
      reader.deprecatedOptions.first.describe(),
      allOf(
        contains('"fail_level" is deprecated since 1.1.0'),
        contains('use "fail_on" instead'),
        contains('It names the threshold like the flag.'),
      ),
    );
    expect(read('fail_on: high\n').deprecatedOptions, isEmpty);
  });

  test('rejects the old and the new name side by side', () {
    expect(
      () => read('fail_level: high\nfail_on: low\n'),
      throwsA(
        isA<InspectraConfigException>().having(
          (error) => '$error',
          'message',
          allOf(contains('"fail_level"'), contains('remove one of them')),
        ),
      ),
    );
  });

  test('every rename keeps its section and names a known option', () {
    final recorder = ConfigRecorder();
    InspectraConfig.parse(null, packageName: 'demo', recorder: recorder);
    final known = <String>{
      for (final ConfigEntry entry in recorder.entries) ...<String>[
        entry.key,
        for (
          var end = entry.key.lastIndexOf('.');
          end > 0;
          end = entry.key.lastIndexOf('.', end - 1)
        )
          entry.key.substring(0, end),
      ],
    };
    for (final ConfigDeprecation rename in configDeprecations) {
      final int dot = rename.oldPath.lastIndexOf('.');
      final String section = dot < 0 ? '' : rename.oldPath.substring(0, dot);
      expect(section, rename.section, reason: rename.oldPath);
      expect(known, contains(rename.newPath), reason: rename.newPath);
    }
  });

  test('config lint reports every use of an old name', () {
    final defaults = InspectraConfig.defaults('demo');
    final config = InspectraConfig(
      packageName: 'demo',
      format: defaults.format,
      lint: defaults.lint,
      trivy: defaults.trivy,
      api: defaults.api,
      coverage: defaults.coverage,
      deprecatedOptions: <DeprecatedOption>[
        DeprecatedOption(deprecation: renames.last, path: 'fail_level'),
      ],
    );
    final List<Finding> findings = lintConfig(
      config: config,
      recorder: ConfigRecorder(),
      environment: const <String, String>{},
      knownPaths: const <String>[],
      now: DateTime.utc(2026, 10),
      baselineExists: false,
    );
    expect(findings.single.ruleId, 'CONFIG_DEPRECATED_OPTION');
    expect(findings.single.severity, Severity.low);
    expect(findings.single.title, 'fail_level is deprecated');
  });
}
