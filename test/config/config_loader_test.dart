/*
 * Copyright 2026 Redtronics
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
import 'package:test/test.dart';

/// Tests layered configuration loading and validation.
void main() {
  late Directory directory;

  setUp(() => directory = Directory.systemTemp.createTempSync('cfg_'));
  tearDown(() => directory.deleteSync(recursive: true));

  /// Writes [content] as `inspectra.yaml` into the test directory.
  void writeConfig(String content) =>
      File('${directory.path}/inspectra.yaml').writeAsStringSync(content);

  /// Loads the configuration with [environment] and [overrides].
  InspectraConfig load({
    Map<String, String> environment = const <String, String>{},
    Map<String, String> overrides = const <String, String>{},
    String? explicitPath,
  }) {
    return ConfigLoader(
      environment: Environment(environment),
      workingDirectory: directory.path,
    ).load(overrides: overrides, explicitPath: explicitPath);
  }

  test('uses defaults without a configuration file', () {
    final config = load();
    expect(config.trivy.mode, TrivyMode.auto);
    expect(config.trivy.version, TrivyConfig.pinnedVersion);
    expect(config.trivy.download, isTrue);
    expect(config.network.osvUrl, 'https://api.osv.dev');
    expect(config.failOn, isNull);
  });

  test('reads values from the file', () {
    writeConfig('''
failOn: high
trivy:
  mode: required
  version: 0.70.1
  download: false
  timeout: 5m
  scanners: [vuln, license]
network:
  maxAttempts: 5
''');
    final config = load();
    expect(config.failOn, Severity.high);
    expect(config.trivy.mode, TrivyMode.required);
    expect(config.trivy.version, '0.70.1');
    expect(config.trivy.download, isFalse);
    expect(config.trivy.timeout, const Duration(minutes: 5));
    expect(config.trivy.scanners, <String>['vuln', 'license']);
    expect(config.network.maxAttempts, 5);
  });

  test('environment variables override the file', () {
    writeConfig('trivy:\n  version: 0.70.1\n');
    final config = load(
      environment: <String, String>{
        'INSPECTRA_TRIVY_VERSION': '0.71.0',
        'INSPECTRA_TRIVY_DOWNLOAD_BASE_URL': 'https://mirror.corp/trivy/',
      },
    );
    expect(config.trivy.version, '0.71.0');
    expect(config.trivy.downloadBaseUrl, 'https://mirror.corp/trivy');
  });

  test('command line overrides win over the environment', () {
    final config = load(
      environment: <String, String>{'INSPECTRA_TRIVY_MODE': 'required'},
      overrides: <String, String>{'trivy.mode': 'disabled'},
    );
    expect(config.trivy.mode, TrivyMode.disabled);
  });

  test('PUB_HOSTED_URL becomes the default repository', () {
    final config = load(
      environment: <String, String>{'PUB_HOSTED_URL': 'https://pub.corp/'},
    );
    expect(config.network.pubHostedUrl, 'https://pub.corp');
  });

  test('rejects unknown keys in the file', () {
    writeConfig('trivy:\n  verison: 1\n');
    expect(load, throwsA(isA<InvalidInputException>()));
  });

  test('rejects unknown override keys', () {
    expect(
      () => load(overrides: <String, String>{'trivy.nope': '1'}),
      throwsA(isA<InvalidInputException>()),
    );
  });

  test('rejects invalid values with the origin in the message', () {
    expect(
      () => load(environment: <String, String>{'INSPECTRA_TRIVY_MODE': 'x'}),
      throwsA(
        isA<InvalidInputException>().having(
          (e) => e.message,
          'message',
          contains('INSPECTRA_TRIVY_MODE'),
        ),
      ),
    );
  });

  test('rejects unsupported Trivy scanners', () {
    writeConfig('trivy:\n  scanners: [vuln, rootkit]\n');
    expect(load, throwsA(isA<InvalidInputException>()));
  });

  test('parses ignore rules and requires a reason', () {
    writeConfig('''
ignore:
  - id: GHSA-1
    package: http
    reason: Not reachable.
    expires: 2027-01-31
''');
    final rule = load().ignore.single;
    expect(rule.id, 'GHSA-1');
    expect(rule.package, 'http');
    expect(rule.expires, DateTime(2027, 1, 31));
    writeConfig('ignore:\n  - id: GHSA-1\n');
    expect(load, throwsA(isA<InvalidInputException>()));
  });

  test('fails for a missing explicit configuration file', () {
    expect(
      () => load(explicitPath: 'missing.yaml'),
      throwsA(isA<InvalidInputException>()),
    );
  });

  test('fails for malformed YAML', () {
    writeConfig('trivy: [unclosed');
    expect(load, throwsA(isA<InvalidInputException>()));
  });
}
