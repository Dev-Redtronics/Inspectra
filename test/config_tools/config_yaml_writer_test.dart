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
import 'package:inspectra/src/config_tools/config_yaml_writer.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Tests writing the effective configuration as YAML.
void main() {
  /// Creates the entry of [key] with [value] from [origin].
  ConfigEntry entry(
    String key,
    Object? value, {
    ConfigOrigin origin = ConfigOrigin.defaults,
    String? variable,
    int? line,
  }) => ConfigEntry(
    key: key,
    kind: ConfigKind.string,
    value: value,
    defaultValue: null,
    origin: origin,
    variable: variable,
    line: line,
  );

  test('nests sections and quotes texts that YAML would misread', () {
    final String yaml = writeConfigYaml(<ConfigEntry>[
      entry('fail_on', 'high'),
      entry('trivy.version', '0.75.0'),
      entry('trivy.secret.include', <Object?>['**.dart', 'lib/a.dart']),
      entry('trivy.report_directory', '.dart_tool/inspectra/trivy'),
      entry('changelog.tag_prefix', ''),
      entry('changelog.commit_url', '{repository}/commit/{hash}'),
      entry('network.retries', 'yes'),
      entry('network.version', '1.0'),
      entry('network.quote', "it's"),
      entry('network.enabled', true),
      entry('network.width', 80),
      entry('format.page_width', null),
    ]);
    expect(yaml, '''
fail_on: high
trivy:
  version: 0.75.0
  secret:
    include: ['**.dart', lib/a.dart]
  report_directory: .dart_tool/inspectra/trivy
changelog:
  tag_prefix: ''
  commit_url: '{repository}/commit/{hash}'
network:
  retries: 'yes'
  version: '1.0'
  quote: 'it''s'
  enabled: true
  width: 80
format:
  # page_width:
''');
    final parsed = loadYaml(yaml) as YamlMap;
    expect((parsed['changelog'] as YamlMap)['commit_url'], contains('{hash}'));
    expect((parsed['network'] as YamlMap)['retries'], 'yes');
    expect((parsed['network'] as YamlMap)['quote'], "it's");
  });

  test('explains every value at the comment column', () {
    final String yaml = writeConfigYaml(
      <ConfigEntry>[
        entry('lint.fail_on', 'warning', origin: ConfigOrigin.file, line: 4),
        entry(
          'trivy.mode',
          'required',
          origin: ConfigOrigin.environment,
          variable: 'INSPECTRA_TRIVY_MODE',
        ),
        entry('trivy.version', 'latest', origin: ConfigOrigin.commandLine),
        entry('trivy.timeout', '10m'),
        entry('trivy.executable', null),
        entry(
          'trivy.download_base_url',
          'https://github.com/aquasecurity/trivy/releases/download',
        ),
      ],
      explain: true,
      source: 'inspectra.yaml',
    );
    final List<String> lines = yaml.trimRight().split('\n');
    const mode =
        '  mode: required                     '
        '# environment variable INSPECTRA_TRIVY_MODE';
    const download =
        '  download_base_url: '
        'https://github.com/aquasecurity/trivy/releases/download # default';
    expect(lines, <String>[
      'lint:',
      '  fail_on: warning                   # inspectra.yaml:4',
      'trivy:',
      mode,
      '  version: latest                    # command line',
      '  timeout: 10m                       # default',
      '  # executable:                      # unset',
      download,
    ]);
    expect(lines[1].indexOf('#'), commentColumn);
  });

  test('writes the ignore list as a block and an empty one as flow', () {
    final String yaml = writeConfigYaml(<ConfigEntry>[
      entry('ignore', <Object?>[
        <String, Object?>{'id': 'GHSA-1', 'reason': 'Not reachable: tested.'},
      ]),
      entry('typosquat.allow', <Object?>[]),
    ]);
    expect(yaml, '''
ignore:
  - id: GHSA-1
    reason: 'Not reachable: tested.'
typosquat:
  allow: []
''');
    expect(writeConfigYaml(const <ConfigEntry>[]), isEmpty);
  });

  test('a file value without a line names the file only', () {
    expect(
      describeOrigin(entry('a', 'b', origin: ConfigOrigin.file)),
      'configuration file',
    );
    expect(
      describeOrigin(
        entry('a', 'b', origin: ConfigOrigin.file),
        source: 'x.yaml',
      ),
      'x.yaml',
    );
    expect(quoteYaml('~'), "'~'");
    expect(quoteYaml('null'), "'null'");
  });
}
