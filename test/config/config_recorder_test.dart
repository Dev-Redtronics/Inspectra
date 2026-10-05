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
import 'package:inspectra/src/config/config_suggestion.dart';
import 'package:test/test.dart';

/// Tests recording the effective configuration with the origin of every
/// value.
void main() {
  /// Parses the `inspectra.yaml` [text] with the command line overrides
  /// [cli] and the [environment].
  ///
  /// Returns the recorder.
  ConfigRecorder record(
    String? text, {
    Map<String, String> cli = const <String, String>{},
    Map<String, String> environment = const <String, String>{},
  }) {
    final recorder = ConfigRecorder();
    InspectraConfig.fromSources(
      pubspec: 'name: demo\n',
      configFile: text,
      overrides: ConfigOverrides(
        cli: cli,
        environment: Environment(environment),
      ),
      recorder: recorder,
    );
    return recorder;
  }

  /// Returns the entry of [key] in [recorder].
  ConfigEntry entry(ConfigRecorder recorder, String key) {
    final ConfigEntry? found = recorder[key];
    if (found == null) {
      fail('$key was not recorded.');
    }
    return found;
  }

  test('records defaults, file values with lines, variables and flags', () {
    final ConfigRecorder recorder = record(
      'trivy:\n  timeout: 2m\n  mode: required\nlint:\n  fail_on: warning\n',
      cli: <String, String>{'trivy.version': 'latest'},
      environment: <String, String>{'INSPECTRA_TRIVY_MODE': 'disabled'},
    );
    expect(recorder.source, 'inspectra.yaml');
    final ConfigEntry timeout = entry(recorder, 'trivy.timeout');
    expect(timeout.kind, ConfigKind.duration);
    expect(timeout.value, '2m');
    expect(timeout.defaultValue, '10m');
    expect(timeout.origin, ConfigOrigin.file);
    expect(timeout.line, 2);
    final ConfigEntry mode = entry(recorder, 'trivy.mode');
    expect(mode.value, 'disabled');
    expect(mode.origin, ConfigOrigin.environment);
    expect(mode.variable, 'INSPECTRA_TRIVY_MODE');
    expect(mode.options, <String>['auto', 'required', 'disabled']);
    final ConfigEntry version = entry(recorder, 'trivy.version');
    expect(version.value, 'latest');
    expect(version.origin, ConfigOrigin.commandLine);
    final ConfigEntry failOn = entry(recorder, 'lint.fail_on');
    expect(failOn.toJson(), <String, Object?>{
      'key': 'lint.fail_on',
      'value': 'warning',
      'default': 'info',
      'origin': 'file',
      'line': 5,
    });
    final ConfigEntry attempts = entry(recorder, 'network.max_attempts');
    expect(attempts.value, 3);
    expect(attempts.origin, ConfigOrigin.defaults);
    expect(attempts.minimum, 1);
    expect(attempts.maximum, 100);
  });

  test('records lists, enum lists, optional values and the ignore list', () {
    final ConfigRecorder recorder = record(
      'ignore:\n  - id: GHSA-1\n    reason: Not reachable.\n'
      'trivy:\n  filesystem:\n    scanners: [VULN]\n',
    );
    final ConfigEntry scanners = entry(recorder, 'trivy.filesystem.scanners');
    expect(scanners.kind, ConfigKind.enumList);
    expect(scanners.value, <String>['vuln']);
    expect(scanners.defaultValue, <String>['vuln', 'secret', 'misconfig']);
    expect(entry(recorder, 'trivy.secret.severity').value, <String>[
      'CRITICAL',
      'HIGH',
      'MEDIUM',
      'LOW',
    ]);
    expect(entry(recorder, 'format.page_width').value, isNull);
    final ConfigEntry ignore = entry(recorder, 'ignore');
    expect(ignore.kind, ConfigKind.structured);
    expect(ignore.value, <Object?>[
      <String, Object?>{'id': 'GHSA-1', 'reason': 'Not reachable.'},
    ]);
    expect(ignore.line, 1);
    expect(entry(record(null), 'ignore').value, isEmpty);
  });

  test('records a style rule once, and only when it is mentioned', () {
    final ConfigRecorder recorder = record(
      'style:\n  rules:\n    no_else: false\n',
    );
    final ConfigEntry noElse = entry(recorder, 'style.rules.no_else');
    expect(noElse.value, isFalse);
    expect(noElse.origin, ConfigOrigin.file);
    final ConfigEntry other = entry(recorder, 'style.rules.public_docs');
    expect(other.value, isNull);
    expect(other.origin, ConfigOrigin.defaults);
  });

  test('records defaults that come from the environment', () {
    final ConfigRecorder recorder = record(
      null,
      environment: <String, String>{
        'PUB_HOSTED_URL': 'https://pub.corp/',
        'INSPECTRA_TRIVY': '/opt/trivy',
      },
    );
    final ConfigEntry pub = entry(recorder, 'network.pub_hosted_url');
    expect(pub.value, 'https://pub.corp/');
    expect(pub.origin, ConfigOrigin.environment);
    expect(pub.variable, 'PUB_HOSTED_URL');
    expect(pub.defaultValue, 'https://pub.corp/');
    final ConfigEntry trivy = entry(recorder, 'trivy.executable');
    expect(trivy.value, '/opt/trivy');
    expect(trivy.variable, 'INSPECTRA_TRIVY');
    expect(recorder.source, isNull);
  });

  test('an empty tag prefix is a value of its own', () {
    final config = InspectraConfig.fromSources(
      pubspec: 'name: demo\ninspectra:\n  changelog:\n    tag_prefix: ""\n',
    );
    expect(config.changelog.tagPrefix, isEmpty);
    final ConfigRecorder recorder = record('changelog:\n  tag_prefix: ""\n');
    expect(entry(recorder, 'changelog.tag_prefix').value, '');
    final ConfigRecorder overridden = record(
      'changelog:\n  tag_prefix: ""\n',
      cli: <String, String>{'changelog.tag_prefix': 'release-'},
    );
    expect(entry(overridden, 'changelog.tag_prefix').value, 'release-');
  });

  test('the pubspec section is the source of the values in it', () {
    final recorder = ConfigRecorder();
    InspectraConfig.fromSources(
      pubspec: 'name: demo\ninspectra:\n  lint:\n    enabled: true\n',
      recorder: recorder,
    );
    expect(recorder.source, 'pubspec.yaml');
    expect(entry(recorder, 'lint.enabled').line, 4);
    final empty = ConfigRecorder();
    InspectraConfig.fromSources(pubspec: 'name: demo\n', recorder: empty);
    expect(empty.source, isNull);
  });

  test('formats durations in their largest unit', () {
    expect(ConfigEntry.formatDuration(const Duration(hours: 2)), '2h');
    expect(ConfigEntry.formatDuration(const Duration(minutes: 90)), '90m');
    expect(ConfigEntry.formatDuration(const Duration(seconds: 3)), '3s');
    expect(
      ConfigEntry.formatDuration(const Duration(milliseconds: 1500)),
      '1500ms',
    );
    expect(ConfigEntry.formatDuration(Duration.zero), '0s');
    expect(ConfigEntry.jsonOf(DateTime.utc(2026)), contains('2026'));
  });

  group('suggestions', () {
    test('a misspelled key in the file names the closest option', () {
      expect(
        () => record('trivy:\n  secrets: {}\n'),
        throwsA(
          isA<InspectraConfigException>().having(
            (e) => e.message,
            'message',
            contains('Did you mean "secret"?'),
          ),
        ),
      );
    });

    test('a misspelled key of an ignore rule names the closest one', () {
      expect(
        () => record('ignore:\n  - id: A\n    reason: B\n    expire: x\n'),
        throwsA(
          isA<InspectraConfigException>().having(
            (e) => e.message,
            'message',
            contains('Did you mean "expires"?'),
          ),
        ),
      );
    });

    test('a misspelled override names the closest option', () {
      expect(
        () => record(null, cli: <String, String>{'trivy.verison': '1'}),
        throwsA(
          isA<InspectraConfigException>().having(
            (e) => e.message,
            'message',
            contains('Did you mean "trivy.version"?'),
          ),
        ),
      );
    });

    test('nothing is suggested for a name that resembles no option', () {
      expect(closestName('frobnicate', <String>['enabled', 'mode']), isNull);
      expect(didYouMean('frobnicate', <String>['enabled']), isEmpty);
      expect(closestName('mod', <String>['mode', 'model']), 'mode');
    });
  });
}
