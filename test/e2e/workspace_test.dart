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

import 'package:test/test.dart';

import '../support/fake_git.dart';
import '../support/test_harness.dart';

/// Runs the workspace policy, `graph` and `workspace affected` in-process.
void main() {
  final harnesses = <TestHarness>[];

  tearDown(() {
    for (final harness in harnesses) {
      harness.dispose();
    }
    harnesses.clear();
  });

  /// A member pubspec named [name] with the [dependencies] section text.
  String member(String name, [String dependencies = '']) =>
      'name: $name\nresolution: workspace\n'
      '${dependencies.isEmpty ? '' : 'dependencies:\n$dependencies'}';

  const policy = '''
workspace_policy:
  enabled: true
  layers:
    - name: app
      packages: [apps/*]
    - name: feature
      packages: [features/*]
      may_depend_on: [core]
      isolated: true
    - name: core
      packages: [packages/*]
      may_depend_on: []
''';

  /// Creates a workspace of an app, two features and a core package, the
  /// features depending on each other, with Git answering [git].
  TestHarness workspace({FakeGit? git, String config = policy}) {
    final harness = TestHarness.withFiles(<String, String>{
      'pubspec.yaml':
          'name: root\npublish_to: none\n'
          'workspace: [apps/shop, features/cart, features/search, '
          'packages/core]\n',
      'inspectra.yaml': config,
      'apps/shop/pubspec.yaml': member('shop', '  cart: any\n  core: any\n'),
      'features/cart/pubspec.yaml': member(
        'cart',
        '  core: any\n  search: any\n',
      ),
      'features/search/pubspec.yaml': member('search', '  core: any\n'),
      'packages/core/pubspec.yaml': member('core'),
    }, processRunner: git?.runner);
    harnesses.add(harness);
    return harness;
  }

  /// Returns `ruleId package` of the findings of the JSON report in
  /// [harness].
  List<String> findings(TestHarness harness) {
    final report = jsonDecode(harness.out) as Map<String, Object?>;
    final List<Map<String, Object?>> entries =
        (report['findings']! as List<Object?>).cast<Map<String, Object?>>();
    return <String>[
      for (final entry in entries) '${entry['ruleId']} ${entry['package']}',
    ];
  }

  test('deps -r and check apply the workspace policy', () async {
    final TestHarness harness = workspace();
    expect(
      await harness.run(<String>['deps', '-r', '-f', 'json']),
      1,
      reason: harness.err,
    );
    expect(findings(harness), <String>['LAYER_VIOLATION search']);
    final report = jsonDecode(harness.out) as Map<String, Object?>;
    expect(report['pubspecs'], hasLength(5));
    final TestHarness check = workspace();
    expect(await check.run(<String>['check']), 1);
    expect(check.out, contains('Workspace policy: '));
    expect(check.out, contains('(LAYER_VIOLATION)'));
  });

  test('--changed-since checks the affected packages only', () async {
    final git = FakeGit(
      changes: const <String, List<String>>{
        'main': <String>['features/search/lib/search.dart'],
        'docs': <String>['README.md'],
      },
    );
    final TestHarness harness = workspace(
      git: git,
      config: 'fail_on: critical\n',
    );
    expect(
      await harness.run(<String>[
        'deps',
        '-r',
        '--changed-since',
        'main',
        '-f',
        'json',
      ]),
      0,
      reason: harness.err,
    );
    final report = jsonDecode(harness.out) as Map<String, Object?>;
    expect(report['pubspecs'], <String>[
      'apps/shop/pubspec.yaml',
      'features/cart/pubspec.yaml',
      'features/search/pubspec.yaml',
    ]);
    final TestHarness affected = workspace(git: git);
    expect(
      await affected.run(<String>['workspace', 'affected', '--since', 'main']),
      0,
      reason: affected.err,
    );
    expect(affected.out, 'apps/shop\nfeatures/cart\nfeatures/search\n');
    final TestHarness json = workspace(git: git);
    expect(
      await json.run(<String>[
        'workspace',
        'affected',
        '--since',
        'docs',
        '-f',
        'json',
      ]),
      0,
    );
    final listing = jsonDecode(json.out) as Map<String, Object?>;
    expect(listing['packages'], <Object?>[
      <String, Object?>{'name': 'root', 'path': '.'},
    ]);
    final TestHarness unknown = workspace(git: git);
    expect(
      await unknown.run(<String>['workspace', 'affected', '--since', 'gone']),
      64,
    );
  });

  test('graph draws the workspace with its layers', () async {
    final TestHarness harness = workspace();
    expect(await harness.run(<String>['graph']), 0, reason: harness.err);
    expect(harness.out, contains('cart [feature] -> core, search'));
    final TestHarness mermaid = workspace();
    expect(
      await mermaid.run(<String>['graph', '-f', 'mermaid']),
      0,
      reason: mermaid.err,
    );
    expect(mermaid.out, startsWith('flowchart LR\n'));
    expect(mermaid.out, contains('  subgraph layer1 ["feature"]'));
    expect(mermaid.out, contains('  shop --> cart'));
    final TestHarness dot = workspace();
    expect(await dot.run(<String>['graph', '-f', 'dot']), 0);
    expect(dot.out, contains('"cart" -> "search";'));
    final single = TestHarness.withFiles(<String, String>{
      'pubspec.yaml':
          'name: app\ndependencies:\n  http: ^1.2.0\n  flutter:\n'
          '    sdk: flutter\n',
    });
    harnesses.add(single);
    expect(await single.run(<String>['graph', '-f', 'json']), 0);
    final graph = jsonDecode(single.out) as Map<String, Object?>;
    expect(graph['edges'], <Object?>[
      <String, Object?>{'from': 'app', 'to': 'http', 'external': true},
    ]);
  });
}
