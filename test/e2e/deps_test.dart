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

import '../support/fake_http_server.dart';
import '../support/fake_response.dart';
import '../support/test_harness.dart';

/// Runs `inspectra deps` and the dependency policy of `scan` and `check`
/// in-process.
void main() {
  late FakeHttpServer server;
  final harnesses = <TestHarness>[];

  setUp(() async => server = await FakeHttpServer.start());
  tearDown(() async {
    await server.close();
    for (final harness in harnesses) {
      harness.dispose();
    }
    harnesses.clear();
  });

  /// Creates a project with [files] whose services point at the fake
  /// server.
  TestHarness project(Map<String, String> files) {
    final harness = TestHarness.withFiles(
      files,
      environment: <String, String>{
        'INSPECTRA_NETWORK_OSV_URL': server.baseUrl,
        'INSPECTRA_NETWORK_PUB_HOSTED_URL': server.baseUrl,
        'INSPECTRA_NETWORK_MAX_ATTEMPTS': '1',
      },
    );
    harnesses.add(harness);
    return harness;
  }

  /// Runs [arguments] in [harness] with fresh output buffers.
  ///
  /// Returns the exit code.
  Future<int> run(TestHarness harness, List<String> arguments) {
    (harness.context.out as StringBuffer).clear();
    (harness.context.err as StringBuffer).clear();
    return harness.run(arguments);
  }

  /// Returns the rule ids of the findings of the JSON report in [harness].
  List<Object?> rules(TestHarness harness) {
    final report = jsonDecode(harness.out) as Map<String, Object?>;
    return <Object?>[
      for (final Object? finding in report['findings']! as List<Object?>)
        (finding! as Map<String, Object?>)['ruleId'],
    ];
  }

  const policy = '''
inspectra:
  dependency_policy:
    enabled: true
    require_upper_bound: true
    dev_only: [mockito]
    require_publish_to: true
''';

  const app = '''
name: app # the app
environment:
  sdk: ^3.6.0
dependencies:
  # networking
  http: ">=1.2.0"
  mockito: ^5.4.0
$policy''';

  test('the pubspec rules run without a policy and without network', () async {
    final TestHarness harness = project(<String, String>{
      'pubspec.yaml': 'name: app\ndependencies:\n  http: any\n',
    });
    expect(await run(harness, <String>['deps', '-f', 'json']), 1);
    expect(rules(harness), <Object?>['ANY_VERSION']);
    final TestHarness clean = project(<String, String>{
      'pubspec.yaml': 'name: app\ndependencies:\n  http: ^1.2.0\n',
    });
    expect(await run(clean, <String>['deps']), 0);
    expect(clean.out, contains('follow the rules'));
  });

  test('reports the policy and fixes what can be fixed', () async {
    final TestHarness harness = project(<String, String>{'pubspec.yaml': app});
    expect(await run(harness, <String>['deps', '-f', 'json']), 1);
    expect(rules(harness), <Object?>[
      'MISSING_UPPER_BOUND',
      'DEV_ONLY_DEPENDENCY',
      'MISSING_PUBLISH_TO',
    ]);
    expect(
      await run(harness, <String>['deps', '--fix', '-f', 'json']),
      0,
      reason: harness.out,
    );
    final report = jsonDecode(harness.out) as Map<String, Object?>;
    expect(report['fixed'], <String>[
      'pubspec.yaml: http: >=1.2.0 -> ^1.2.0',
      'pubspec.yaml: mockito: dependencies -> dev_dependencies',
      'pubspec.yaml: publish_to: none',
    ]);
    final String fixed = File('${harness.workingDirectory}/pubspec.yaml')
        .readAsStringSync();
    expect(fixed, startsWith('name: app # the app\npublish_to: none\n'));
    expect(fixed, contains('  # networking\n  http: ^1.2.0\n'));
    expect(fixed, contains('dev_dependencies:\n  mockito: ^5.4.0\n'));
    expect(await run(harness, <String>['deps', '--fix']), 0);
    expect(harness.out, isNot(contains('Fixed')));
  });

  test('--fix without a policy changes nothing and says so', () async {
    final TestHarness harness = project(<String, String>{
      'pubspec.yaml': 'name: app\n',
    });
    expect(await run(harness, <String>['deps', '--fix']), 0);
    expect(harness.err, contains('Nothing to fix'));
  });

  test('checks the members of a workspace with -r', () async {
    final TestHarness harness = project(<String, String>{
      'pubspec.yaml':
          'name: root\npublish_to: none\nworkspace: [pkgs/core]\n$policy',
      'pkgs/core/pubspec.yaml':
          'name: core\nresolution: workspace\n'
          'dependencies:\n  collection: ">=1.0.0"\n',
    });
    expect(await run(harness, <String>['deps', '-f', 'json']), 0);
    expect(await run(harness, <String>['deps', '-r', '-f', 'json']), 1);
    final report = jsonDecode(harness.out) as Map<String, Object?>;
    expect(report['pubspecs'], <String>[
      'pkgs/core/pubspec.yaml',
      'pubspec.yaml',
    ]);
    expect(rules(harness), <Object?>[
      'MISSING_UPPER_BOUND',
      'MISSING_PUBLISH_TO',
    ]);
  });

  test('ignore rules and the baseline apply', () async {
    final TestHarness harness = project(<String, String>{
      'pubspec.yaml':
          '''
name: app
publish_to: none
dependencies:
  http: ">=1.2.0"
  mockito: ^5.4.0
$policy
  ignore:
    - id: DEV_ONLY_DEPENDENCY
      reason: Generated mocks ship with the package.
      expires: 2027-01-31
''',
      'inspectra-baseline.json': jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'entries': <Object?>[
          <String, Object?>{
            'scope': 'scan',
            'source': 'pubspec',
            'rule': 'MISSING_UPPER_BOUND',
            'package': 'http',
            'path': 'pubspec.yaml',
            'count': 1,
            'severity': 'medium',
            'title': 'recorded',
          },
        ],
      }),
    });
    expect(
      await run(harness, <String>['deps', '-f', 'json']),
      0,
      reason: harness.out,
    );
    final report = jsonDecode(harness.out) as Map<String, Object?>;
    expect(report['suppressed'], 1);
    expect(report['baselined'], 1);
  });

  test('a missing pubspec is an input error', () async {
    final TestHarness harness = project(<String, String>{'README.md': '# x'});
    expect(await run(harness, <String>['deps']), 65);
    expect(harness.err, contains('No pubspec.yaml found'));
  });

  test('scan and check apply the policy', () async {
    server.on(
      'POST',
      '/v1/querybatch',
      FakeResponse.json(<String, Object?>{
        'results': <Object?>[<String, Object?>{}],
      }),
    );
    final TestHarness harness = project(<String, String>{
      'pubspec.yaml': app,
      'pubspec.lock': '''
packages:
  http:
    dependency: "direct main"
    description: {name: http, sha256: aa, url: "https://pub.dev"}
    source: hosted
    version: "1.2.0"
''',
    });
    expect(
      await run(harness, <String>[
        'scan',
        '--trivy-mode',
        'disabled',
        '-f',
        'json',
      ]),
      1,
      reason: harness.err,
    );
    expect(
      rules(harness),
      containsAll(<String>[
        'MISSING_UPPER_BOUND',
        'DEV_ONLY_DEPENDENCY',
        'MISSING_PUBLISH_TO',
      ]),
    );
    expect(await run(harness, <String>['check']), 1);
    expect(harness.out, contains('Dependency policy: '));
    expect(harness.out, contains('(MISSING_PUBLISH_TO)'));
  });
}
