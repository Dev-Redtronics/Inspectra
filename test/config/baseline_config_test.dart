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

/// Tests reading the `baseline:` section of the configuration.
void main() {
  /// Parses the `baseline:` section [section] with the command line
  /// overrides [cli] and the environment [environment].
  BaselineConfig parse(
    Map<String, Object?>? section, {
    Map<String, String> cli = const <String, String>{},
    Map<String, String> environment = const <String, String>{},
  }) => InspectraConfig.parse(
    <String, Object?>{'baseline': section},
    packageName: 'demo',
    overrides: ConfigOverrides(cli: cli, environment: Environment(environment)),
  ).baseline;

  test('has defaults', () {
    final BaselineConfig config = parse(null);
    expect(config.enabled, isTrue);
    expect(config.file, 'inspectra-baseline.json');
    expect(config.maxSeverity, isNull);
    expect(config.failOnStale, isFalse);
    expect(InspectraConfig.defaults('demo').baseline.file, config.file);
  });

  test('reads every key', () {
    final BaselineConfig config = parse(<String, Object?>{
      'enabled': false,
      'file': 'ci/baseline.json',
      'max_severity': 'high',
      'fail_on_stale': true,
    });
    expect(config.enabled, isFalse);
    expect(config.file, 'ci/baseline.json');
    expect(config.maxSeverity, Severity.high);
    expect(config.failOnStale, isTrue);
  });

  test('is overridden on the command line and by the environment', () {
    final BaselineConfig config = parse(
      null,
      cli: <String, String>{'baseline.enabled': 'false'},
      environment: <String, String>{'INSPECTRA_BASELINE_FILE': 'other.json'},
    );
    expect(config.enabled, isFalse);
    expect(config.file, 'other.json');
  });

  test('rejects unknown keys and severities', () {
    expect(
      () => parse(<String, Object?>{'files': 'x'}),
      throwsA(
        isA<InspectraConfigException>().having(
          (e) => e.path,
          'path',
          'baseline.files',
        ),
      ),
    );
    expect(
      () => parse(<String, Object?>{'max_severity': 'severe'}),
      throwsA(
        isA<InspectraConfigException>().having(
          (e) => e.message,
          'message',
          contains('critical'),
        ),
      ),
    );
  });
}
