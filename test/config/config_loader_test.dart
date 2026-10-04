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

  setUp(() {
    directory = Directory.systemTemp.createTempSync('cfg_');
    File('${directory.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
  });
  tearDown(() => directory.deleteSync(recursive: true));

  /// Writes [content] as `inspectra.yaml` into the test directory.
  void writeConfig(String content) =>
      File('${directory.path}/inspectra.yaml').writeAsStringSync(content);

  /// Loads the configuration with [environment] and [cli] overrides.
  InspectraConfig load({
    Map<String, String> environment = const <String, String>{},
    Map<String, String> cli = const <String, String>{},
    String? configFile,
  }) => loadConfig(
    directory.path,
    overrides: ConfigOverrides(cli: cli, environment: Environment(environment)),
    configFile: configFile,
  );

  test('uses defaults without a configuration file', () {
    final InspectraConfig config = load();
    expect(config.packageName, 'demo');
    expect(config.trivy.mode, TrivyMode.auto);
    expect(config.trivy.version, TrivyConfig.pinnedVersion);
    expect(config.trivy.download, isTrue);
    expect(config.trivy.enabled, isFalse);
    expect(config.network.osvUrl, 'https://api.osv.dev');
    expect(config.failOn, isNull);
  });

  test('reads values from the file', () {
    writeConfig('''
fail_on: high
trivy:
  mode: required
  version: 0.70.1
  download: false
  timeout: 5m
  filesystem:
    scanners: [vuln, license]
network:
  max_attempts: 5
''');
    final InspectraConfig config = load();
    expect(config.failOn, Severity.high);
    expect(config.trivy.mode, TrivyMode.required);
    expect(config.trivy.version, '0.70.1');
    expect(config.trivy.download, isFalse);
    expect(config.trivy.timeout, const Duration(minutes: 5));
    expect(config.trivy.filesystem.scanners, <String>['vuln', 'license']);
    expect(config.network.maxAttempts, 5);
  });

  test('reads the inspectra section of pubspec.yaml', () {
    File('${directory.path}/pubspec.yaml').writeAsStringSync(
      'name: demo\ninspectra:\n  typosquat:\n    allow: [htpp]\n',
    );
    expect(load().typosquat.allow, <String>['htpp']);
  });

  test('environment variables override the file', () {
    writeConfig('trivy:\n  version: 0.70.1\n');
    final InspectraConfig config = load(
      environment: <String, String>{
        'INSPECTRA_TRIVY_VERSION': '0.71.0',
        'INSPECTRA_TRIVY_DOWNLOAD_BASE_URL': 'https://mirror.corp/trivy/',
        'INSPECTRA_TRIVY_FILESYSTEM_SCANNERS': 'vuln,secret',
      },
    );
    expect(config.trivy.version, '0.71.0');
    expect(config.trivy.downloadBaseUrl, 'https://mirror.corp/trivy');
    expect(config.trivy.filesystem.scanners, <String>['vuln', 'secret']);
  });

  test('INSPECTRA_TRIVY names the executable', () {
    final InspectraConfig config = load(
      environment: <String, String>{'INSPECTRA_TRIVY': '/opt/trivy'},
    );
    expect(config.trivy.executable, '/opt/trivy');
  });

  test('command line overrides win over the environment', () {
    final InspectraConfig config = load(
      environment: <String, String>{'INSPECTRA_TRIVY_MODE': 'required'},
      cli: <String, String>{'trivy.mode': 'disabled'},
    );
    expect(config.trivy.mode, TrivyMode.disabled);
  });

  test('PUB_HOSTED_URL becomes the default repository', () {
    final InspectraConfig config = load(
      environment: <String, String>{'PUB_HOSTED_URL': 'https://pub.corp/'},
    );
    expect(config.network.pubHostedUrl, 'https://pub.corp');
  });

  test('rejects unknown keys in the file', () {
    writeConfig('trivy:\n  verison: 1\n');
    expect(load, throwsA(isA<InspectraConfigException>()));
  });

  test('rejects unknown override keys', () {
    expect(
      () => load(cli: <String, String>{'trivy.nope': '1'}),
      throwsA(isA<InspectraConfigException>()),
    );
  });

  test('rejects invalid values with the key in the message', () {
    expect(
      () => load(environment: <String, String>{'INSPECTRA_TRIVY_MODE': 'x'}),
      throwsA(
        isA<InspectraConfigException>().having(
          (e) => e.path,
          'path',
          'trivy.mode',
        ),
      ),
    );
    expect(
      () => load(
        environment: <String, String>{'INSPECTRA_NETWORK_TIMEOUT': 'soon'},
      ),
      throwsA(isA<InspectraConfigException>()),
    );
    expect(
      () => load(cli: <String, String>{'trivy.download': 'maybe'}),
      throwsA(isA<InspectraConfigException>()),
    );
  });

  test('rejects unsupported Trivy scanners', () {
    writeConfig('trivy:\n  filesystem:\n    scanners: [vuln, rootkit]\n');
    expect(load, throwsA(isA<InspectraConfigException>()));
  });

  test('parses ignore rules and requires a reason', () {
    writeConfig('''
ignore:
  - id: GHSA-1
    package: http
    reason: Not reachable.
    expires: 2027-01-31
''');
    final IgnoreRule rule = load().ignore.single;
    expect(rule.id, 'GHSA-1');
    expect(rule.package, 'http');
    expect(rule.expires, DateTime(2027, 1, 31));
    writeConfig('ignore:\n  - id: GHSA-1\n');
    expect(load, throwsA(isA<InspectraConfigException>()));
    writeConfig('ignore:\n  - id: X\n    reason: r\n    expires: soon\n');
    expect(load, throwsA(isA<InspectraConfigException>()));
    writeConfig('ignore: nope\n');
    expect(load, throwsA(isA<InspectraConfigException>()));
  });

  test('fails for a missing explicit configuration file', () {
    expect(
      () => load(configFile: 'missing.yaml'),
      throwsA(isA<InspectraConfigException>()),
    );
  });

  test('fails for malformed YAML', () {
    writeConfig('trivy: [unclosed');
    expect(load, throwsA(isA<InspectraConfigException>()));
  });

  test('works outside of a package when allowed', () {
    File('${directory.path}/pubspec.yaml').deleteSync();
    expect(load, throwsA(isA<FileSystemException>()));
    final InspectraConfig config = loadConfig(
      directory.path,
      requirePubspec: false,
    );
    expect(config.packageName, 'package');
  });
}
