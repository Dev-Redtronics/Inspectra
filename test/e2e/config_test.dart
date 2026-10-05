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

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../support/test_harness.dart';

/// Runs `inspectra config` in-process.
void main() {
  final harnesses = <TestHarness>[];

  tearDown(() {
    for (final harness in harnesses) {
      harness.dispose();
    }
    harnesses.clear();
  });

  /// Creates a package with [files] and the [environment].
  TestHarness project(
    Map<String, String> files, {
    Map<String, String> environment = const <String, String>{},
  }) {
    final harness = TestHarness.withFiles(<String, String>{
      'pubspec.yaml': 'name: demo\n',
      ...files,
    }, environment: environment);
    harnesses.add(harness);
    return harness;
  }

  group('show', () {
    test('explains the origin of every value', () async {
      final TestHarness harness = project(
        <String, String>{'inspectra.yaml': 'lint:\n  fail_on: warning\n'},
        environment: <String, String>{'INSPECTRA_TRIVY_MODE': 'required'},
      );
      expect(
        await harness.run(<String>[
          'config',
          'show',
          '--explain',
          '--set',
          'trivy.version=latest',
        ]),
        0,
        reason: harness.err,
      );
      final String out = harness.out;
      expect(out, contains('# The effective Inspectra configuration'));
      expect(
        out,
        contains('  fail_on: warning                   # inspectra.yaml:2'),
      );
      expect(
        out,
        contains(
          '  mode: required                     '
          '# environment variable INSPECTRA_TRIVY_MODE',
        ),
      );
      expect(
        out,
        contains('  version: latest                    # command line'),
      );
      expect(out, contains('  timeout: 10m                       # default'));
    });

    test('shows only the changed values, also as JSON', () async {
      final TestHarness harness = project(<String, String>{
        'inspectra.yaml': 'lint:\n  fail_on: warning\n',
      });
      expect(
        await harness.run(<String>['config', 'show', '--only-changed']),
        0,
      );
      expect(harness.out, endsWith('lint:\n  fail_on: warning\n'));
      final TestHarness json = project(<String, String>{
        'inspectra.yaml': 'lint:\n  fail_on: warning\n',
      });
      expect(
        await json.run(<String>[
          'config',
          'show',
          '--only-changed',
          '-f',
          'json',
        ]),
        0,
      );
      final report = jsonDecode(json.out) as Map<String, Object?>;
      expect(report['command'], 'config show');
      expect(report['source'], 'inspectra.yaml');
      expect(report['values'], <Object?>[
        <String, Object?>{
          'key': 'lint.fail_on',
          'value': 'warning',
          'default': 'info',
          'origin': 'file',
          'line': 2,
        },
      ]);
    });

    test('says so when every value is the default', () async {
      final TestHarness harness = project(const <String, String>{});
      expect(
        await harness.run(<String>['config', 'show', '--only-changed']),
        0,
      );
      expect(harness.out, '# Every option has its default value.\n');
    });

    test('a misspelled option fails with a suggestion', () async {
      final TestHarness harness = project(<String, String>{
        'inspectra.yaml': 'trivy:\n  secrets: {}\n',
      });
      expect(await harness.run(<String>['config', 'show']), 65);
      expect(harness.err, contains('Did you mean "secret"?'));
    });
  });

  group('validate', () {
    test('accepts a configuration whose files exist', () async {
      final TestHarness harness = project(<String, String>{
        'inspectra.yaml':
            'style:\n  license_header: tool/header.txt\n'
            'changelog:\n  enabled: true\n',
        'tool/header.txt': '// Header\n',
        'CHANGELOG.md': '# Changelog\n',
      });
      expect(
        await harness.run(<String>['config', 'validate', '-f', 'json']),
        0,
        reason: harness.err,
      );
      final report = jsonDecode(harness.out) as Map<String, Object?>;
      expect(report['valid'], isTrue);
      expect(report['files'], <String>['tool/header.txt', 'CHANGELOG.md']);
    });

    test('lists every missing file and a malformed baseline', () async {
      final TestHarness harness = project(<String, String>{
        'inspectra.yaml':
            'style:\n  license_header: tool/header.txt\n'
            '  custom_rules: [tool/rules.dart]\n'
            'network:\n  ca_certificates: certs/ca.pem\n'
            'trivy:\n  secret:\n    config: secrets.yaml\n',
        'inspectra-baseline.json': '{}',
      });
      expect(await harness.run(<String>['config', 'validate']), 65);
      final String err = harness.err;
      expect(err, contains('5 problem(s)'));
      expect(err, contains('style.license_header: the file tool/header.txt'));
      expect(err, contains('style.custom_rules: the file tool/rules.dart'));
      expect(err, contains('network.ca_certificates: the file certs/ca.pem'));
      expect(err, contains('trivy.secret.config: the file secrets.yaml'));
      expect(err, contains('baseline.file: The baseline'));
    });
  });

  group('lint', () {
    test('reports risky settings and honours --fail-on and ignore', () async {
      final TestHarness harness = project(
        <String, String>{'inspectra.yaml': 'trivy:\n  version: latest\n'},
        environment: <String, String>{'INSPECTRA_NETWORK_OFLINE': 'true'},
      );
      expect(await harness.run(<String>['config', 'lint', '-f', 'json']), 1);
      final report = jsonDecode(harness.out) as Map<String, Object?>;
      final findings = report['findings']! as List<Object?>;
      expect(findings.map((finding) => (finding! as Map)['ruleId']), <String>[
        'CONFIG_UNKNOWN_VARIABLE',
        'CONFIG_UNPINNED_TRIVY',
      ]);
      expect((findings.last! as Map)['source'], 'config');
      expect((findings.last! as Map)['file'], 'inspectra.yaml');
      expect(
        await harness.run(<String>['config', 'lint', '--fail-on', 'high']),
        0,
      );
    });

    test('ignore rules suppress findings with a reason', () async {
      final TestHarness harness = project(<String, String>{
        'inspectra.yaml':
            'trivy:\n  version: latest\nignore:\n'
            '  - id: CONFIG_UNPINNED_TRIVY\n'
            '    reason: The nightly job tracks the newest Trivy.\n'
            '    expires: 2027-01-31\n',
      });
      expect(await harness.run(<String>['config', 'lint']), 0);
      expect(harness.out, contains('no risky settings'));
      expect(harness.out, contains('1 suppressed by ignore rules'));
    });
  });

  group('schema', () {
    test('prints the schema and writes it to a file', () async {
      final TestHarness harness = project(<String, String>{
        'inspectra.yaml': 'broken: [',
      });
      expect(await harness.run(<String>['config', 'schema']), 0);
      final schema = jsonDecode(harness.out) as Map<String, Object?>;
      expect(schema['title'], 'Inspectra configuration');
      expect(
        await harness.run(<String>[
          'config',
          'schema',
          '-o',
          'schema/inspectra.schema.json',
        ]),
        0,
      );
      final file = File(
        '${harness.workingDirectory}/schema/inspectra.schema.json',
      );
      expect(file.readAsStringSync(), contains('"additionalProperties"'));
    });

    test('fails with 69 when the file cannot be written', () async {
      final TestHarness harness = project(<String, String>{
        'blocked': 'a file, not a directory',
      });
      expect(
        await harness.run(<String>['config', 'schema', '-o', 'blocked/x.json']),
        69,
      );
      expect(harness.err, contains('Cannot write the schema'));
    });
  });
}
