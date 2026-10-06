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
import 'package:inspectra/src/config/config_interpolation.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Tests environment variable references in configuration values.
void main() {
  const environment = Environment(<String, String>{
    'HOST': 'pub.corp',
    'EMPTY': '',
  });

  /// Resolves [text] against the test environment.
  ///
  /// Returns the resolved text.
  String resolve(String text) =>
      interpolate(text, environment, path: 'network.proxy');

  test('replaces references and keeps everything else', () {
    expect(resolve(r'https://${env:HOST}/api'), 'https://pub.corp/api');
    expect(resolve(r'${env:PORT:-8080}'), '8080');
    expect(resolve(r'${env:HOST:-other}'), 'pub.corp');
    expect(resolve(r'${env:EMPTY:-fallback}'), 'fallback');
    expect(resolve(r'$${env:HOST}'), r'${env:HOST}');
    expect(resolve(r'cost: $5'), r'cost: $5');
    expect(isInterpolated(r'a ${env:B}'), isTrue);
    expect(isInterpolated(r'a $b'), isFalse);
  });

  test('rejects unset variables and malformed references', () {
    expect(
      () => resolve(r'${env:MISSING}'),
      throwsA(
        isA<InspectraConfigException>().having(
          (error) => '$error',
          'message',
          allOf(contains('"network.proxy"'), contains('MISSING is not set')),
        ),
      ),
    );
    expect(
      () => resolve(r'${HOST}'),
      throwsA(
        isA<InspectraConfigException>().having(
          (error) => error.message,
          'message',
          contains(r'write ${env:NAME}'),
        ),
      ),
    );
  });

  group('in a configuration', () {
    /// Parses [yaml] with the test environment, recording into [recorder].
    ///
    /// Returns the configuration.
    InspectraConfig parse(String yaml, [ConfigRecorder? recorder]) =>
        InspectraConfig.parse(
          loadYaml(yaml),
          packageName: 'app',
          overrides: ConfigOverrides(environment: environment),
          recorder: recorder,
        );

    test('resolves texts and list elements but shows the templates', () {
      final recorder = ConfigRecorder();
      final InspectraConfig config = parse(
        'network:\n  proxy: http://\${env:HOST}:3128\n'
        'dependency_policy:\n'
        '  allowed_hosts: [https://pub.dev, "https://\${env:HOST}"]\n'
        'fail_on: \${env:FAIL_ON:-high}\n',
        recorder,
      );
      expect(config.network.proxy, 'http://pub.corp:3128');
      expect(config.dependencyPolicy.allowedHosts, <String>[
        'https://pub.dev',
        'https://pub.corp',
      ]);
      expect(config.failOn, Severity.high);
      final ConfigEntry? proxy = recorder['network.proxy'];
      expect(proxy?.value, 'http://pub.corp:3128');
      expect(proxy?.shown, r'http://${env:HOST}:3128');
      expect(proxy?.toJson()['value'], r'http://${env:HOST}:3128');
      expect(proxy?.toJson()['interpolated'], isTrue);
      expect(recorder['dependency_policy.allowed_hosts']?.shown, <String>[
        'https://pub.dev',
        r'https://${env:HOST}',
      ]);
      expect(recorder['fail_on']?.value, 'high');
      expect(recorder['fail_on']?.template, r'${env:FAIL_ON:-high}');
      expect(recorder['trivy.version']?.template, isNull);
    });

    test('a value from the command line is never a template', () {
      final recorder = ConfigRecorder();
      InspectraConfig.parse(
        loadYaml('network:\n  proxy: \${env:HOST}\n'),
        packageName: 'app',
        overrides: ConfigOverrides(
          cli: const <String, String>{'network.proxy': r'${env:HOST}'},
          environment: environment,
        ),
        recorder: recorder,
      );
      expect(recorder['network.proxy']?.value, r'${env:HOST}');
      expect(recorder['network.proxy']?.template, isNull);
    });

    test('an unset variable is a configuration error', () {
      expect(
        () => parse('network:\n  proxy: \${env:PROXY}\n'),
        throwsA(
          isA<InspectraConfigException>().having(
            (error) => '$error',
            'message',
            contains('"network.proxy": the environment variable PROXY'),
          ),
        ),
      );
    });
  });
}
