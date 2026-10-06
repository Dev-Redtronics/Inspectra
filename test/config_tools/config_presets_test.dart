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
import 'package:inspectra/src/config_tools/config_lint.dart';
import 'package:inspectra/src/config_tools/config_preset.dart';
import 'package:inspectra/src/config_tools/config_presets.dart';
import 'package:inspectra/src/config_tools/config_schema.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Tests the starting configurations of `config init`.
void main() {
  test('every preset is a valid configuration without risky settings', () {
    for (final ConfigPreset preset in ConfigPreset.values) {
      for (final flutter in <bool>[false, true]) {
        for (final publishable in <bool>[false, true]) {
          final String text = renderPreset(
            preset,
            flutter: flutter,
            publishable: publishable,
          );
          final reason =
              '${preset.id}, flutter $flutter, published '
              '$publishable';
          expect(
            text,
            startsWith(
              r'# yaml-language-server: $schema='
              '$configSchemaUrl\n',
            ),
            reason: reason,
          );
          final recorder = ConfigRecorder();
          final config = InspectraConfig.parse(
            loadYaml(text),
            packageName: 'demo',
            recorder: recorder,
          );
          final List<Finding> risky = lintConfig(
            config: config,
            recorder: recorder,
            environment: const <String, String>{},
            knownPaths: const <String>[],
            now: DateTime.utc(2026, 10),
            baselineExists: true,
          );
          expect(risky, isEmpty, reason: reason);
          expect(config.format.enabled, isTrue, reason: reason);
          expect(config.dependencyPolicy.enabled, isTrue, reason: reason);
        }
      }
    }
  });

  test('presets differ where the kind of package matters', () {
    /// Parses the preset [preset].
    InspectraConfig parse(
      ConfigPreset preset, {
      bool flutter = false,
      bool publishable = false,
    }) => InspectraConfig.parse(
      loadYaml(
        renderPreset(preset, flutter: flutter, publishable: publishable),
      ),
      packageName: 'demo',
    );

    final InspectraConfig app = parse(ConfigPreset.app, flutter: true);
    expect(app.api.enabled, isFalse);
    expect(app.dependencyPolicy.requirePublishTo, isTrue);
    expect(app.coverage.runner, CoverageRunner.flutter);
    expect(app.coverage.minLineCoverage, 70);
    final InspectraConfig library = parse(ConfigPreset.library);
    expect(library.api.semver, isTrue);
    expect(library.changelog.enabled, isTrue);
    expect(library.dependencyPolicy.requirePublishTo, isFalse);
    expect(library.coverage.runner, CoverageRunner.dart);
    expect(parse(ConfigPreset.plugin).coverage.runner, CoverageRunner.flutter);
    final InspectraConfig enterprise = parse(ConfigPreset.enterprise);
    expect(enterprise.trivy.mode, TrivyMode.required);
    expect(enterprise.baseline.maxSeverity, Severity.medium);
    expect(enterprise.api.enabled, isFalse);
    expect(
      parse(ConfigPreset.enterprise, publishable: true).api.enabled,
      isTrue,
    );
  });

  test('detects the preset from the pubspec', () {
    expect(detectPreset(plugin: true, publishable: false), ConfigPreset.plugin);
    expect(
      detectPreset(plugin: false, publishable: true),
      ConfigPreset.library,
    );
    expect(detectPreset(plugin: false, publishable: false), ConfigPreset.app);
  });
}
