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
import 'package:inspectra/src/config_tools/config_change.dart';
import 'package:inspectra/src/config_tools/config_differ.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Tests comparing two configurations option by option.
void main() {
  /// Records the configuration [yaml] in the environment [environment].
  ///
  /// Returns the recorder.
  ConfigRecorder record(
    String yaml, {
    Map<String, String> environment = const <String, String>{},
  }) {
    final recorder = ConfigRecorder();
    InspectraConfig.parse(
      loadYaml(yaml),
      packageName: 'demo',
      overrides: ConfigOverrides(environment: Environment(environment)),
      recorder: recorder,
    );
    return recorder;
  }

  test('lists the changed options and which of them got weaker', () {
    final List<ConfigChange> changes = diffConfigs(
      record(
        'fail_on: high\ncoverage:\n  min_line_coverage: 80\n'
        'trivy:\n  mode: required\n',
      ),
      record(
        'fail_on: low\ncoverage:\n  min_line_coverage: 70\n'
        'trivy:\n  version: latest\n',
      ),
    );
    expect(
      <String, bool>{for (final change in changes) change.key: change.weaker},
      <String, bool>{
        'trivy.mode': true,
        'trivy.version': false,
        'coverage.min_line_coverage': true,
        'fail_on': false,
      },
    );
    final ConfigChange version = changes.firstWhere(
      (change) => change.key == 'trivy.version',
    );
    expect(version.to, 'latest');
    expect(version.toJson()['from'], isA<String>());
    expect(diffConfigs(record(''), record('')), isEmpty);
  });

  test('compares references as written, strictness as resolved', () {
    final List<ConfigChange> changes = diffConfigs(
      record(r'fail_on: ${env:LEVEL}', environment: {'LEVEL': 'high'}),
      record(r'fail_on: ${env:LEVEL}', environment: {'LEVEL': 'critical'}),
    );
    expect(changes.single.from, r'${env:LEVEL}');
    expect(changes.single.to, r'${env:LEVEL}');
    expect(changes.single.weaker, isTrue);
  });
}
