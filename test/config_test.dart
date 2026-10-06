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
import 'package:test/test.dart';

/// Tests parsing and validation of the configuration.
void main() {
  group('InspectraConfig', () {
    test('enables nothing by default', () {
      final config = InspectraConfig.defaults('demo');

      expect(config.packageName, 'demo');
      expect(config.trivy.enabled, isFalse);
      expect(config.api.enabled, isFalse);
      expect(config.coverage.enabled, isFalse);
    });

    test('has the documented defaults for the scans', () {
      final TrivyConfig trivy = InspectraConfig.defaults('demo').trivy;

      expect(trivy.secret.runOnBuild, isTrue);
      expect(trivy.license.runOnBuild, isFalse);
      expect(trivy.vulnerability.runOnBuild, isFalse);
      expect(trivy.license.severity, [
        Severity.critical,
        Severity.high,
        Severity.unknown,
      ]);
      expect(trivy.license.includeDevDependencies, isFalse);
      expect(trivy.vulnerability.includeDevDependencies, isTrue);
      expect(trivy.filesystem.enabled, isFalse);
    });

    test('names the API dump after the package', () {
      expect(InspectraConfig.defaults('demo').api.output, 'api/demo.api');
    });

    test('reads the inspectra section of pubspec.yaml', () {
      final config = InspectraConfig.fromSources(
        pubspec: '''
name: demo
inspectra:
  trivy:
    enabled: true
    secret:
      severity: [critical, HIGH]
  coverage:
    enabled: true
    min_line_coverage: 85
''',
      );

      expect(config.trivy.enabled, isTrue);
      expect(config.trivy.secret.severity, [Severity.critical, Severity.high]);
      expect(config.coverage.minLineCoverage, 85);
    });

    test('prefers inspectra.yaml over the pubspec section', () {
      final config = InspectraConfig.fromSources(
        pubspec: 'name: demo\ninspectra:\n  api:\n    enabled: false\n',
        configFile: 'api:\n  enabled: true\n  output: public/api.txt\n',
      );

      expect(config.api.enabled, isTrue);
      expect(config.api.output, 'public/api.txt');
    });

    test('rejects an unknown option with its full path', () {
      expect(
        () => InspectraConfig.fromSources(
          pubspec: 'name: demo\ninspectra:\n  trivy:\n    secrets: {}\n',
        ),
        throwsA(
          isA<InspectraConfigException>()
              .having((error) => error.path, 'path', 'inspectra.trivy.secrets')
              .having((error) => error.message, 'message', contains('secret')),
        ),
      );
    });

    test('rejects a value of the wrong type', () {
      expect(
        () => InspectraConfig.parse({
          'trivy': {'enabled': 'yes'},
        }, packageName: 'demo'),
        throwsA(
          isA<InspectraConfigException>().having(
            (error) => error.path,
            'path',
            'trivy.enabled',
          ),
        ),
      );
    });

    test('rejects an unknown severity with its index', () {
      expect(
        () => InspectraConfig.parse({
          'trivy': {
            'vulnerability': {
              'severity': ['HIGH', 'SEVERE'],
            },
          },
        }, packageName: 'demo'),
        throwsA(
          isA<InspectraConfigException>().having(
            (error) => error.path,
            'path',
            'trivy.vulnerability.severity[1]',
          ),
        ),
      );
    });

    test('rejects an empty list of severities', () {
      expect(
        () => InspectraConfig.parse({
          'trivy': {
            'secret': {'severity': <String>[]},
          },
        }, packageName: 'demo'),
        throwsA(
          isA<InspectraConfigException>().having(
            (error) => error.message,
            'message',
            startsWith('expected at least one of'),
          ),
        ),
      );
    });

    test('rejects a threshold outside 0 to 100', () {
      expect(
        () => InspectraConfig.parse({
          'coverage': {'min_line_coverage': 120},
        }, packageName: 'demo'),
        throwsA(isA<InspectraConfigException>()),
      );
    });

    test('rejects an unknown test runner', () {
      expect(
        () => InspectraConfig.parse({
          'coverage': {'runner': 'node'},
        }, packageName: 'demo'),
        throwsA(
          isA<InspectraConfigException>().having(
            (error) => error.path,
            'path',
            'coverage.runner',
          ),
        ),
      );
    });

    test('reports malformed YAML as a configuration error', () {
      expect(
        () => InspectraConfig.fromSources(
          pubspec: 'name: demo\n',
          configFile: 'api: [unclosed',
        ),
        throwsA(
          isA<InspectraConfigException>()
              .having((error) => error.path, 'path', 'inspectra.yaml')
              .having(
                (error) => error.message,
                'message',
                startsWith('line 1,'),
              ),
        ),
      );
    });
  });

  test('Severity parses case-insensitively', () {
    expect(Severity.tryParse('Critical'), Severity.critical);
    expect(Severity.tryParse(' unknown '), Severity.unknown);
    expect(Severity.tryParse('severe'), isNull);
    expect(Severity.high.trivyName, 'HIGH');
  });
}
