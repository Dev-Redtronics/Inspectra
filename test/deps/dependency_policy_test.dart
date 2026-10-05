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
import 'package:inspectra/src/deps/dependency_policy.dart';
import 'package:inspectra/src/deps/policy_source.dart';
import 'package:inspectra/src/pub/lockfile_parser.dart';
import 'package:inspectra/src/pub/pubspec_locator.dart';
import 'package:inspectra/src/pub/pubspec_parser.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

/// Tests the rules of the dependency policy.
void main() {
  /// Checks the [pubspec] with [lock] against [config]; [root] holds the
  /// sources for the import rules, and [owns] tells whether the lockfile
  /// belongs to the package.
  ///
  /// Returns the findings.
  List<Finding> check(
    DependencyPolicyConfig config,
    String pubspec, {
    String? lock,
    String? root,
    bool owns = true,
    String registry = 'https://pub.dev',
  }) {
    final source = PolicySource(
      pubspec: const PubspecParser().parse(pubspec, path: 'pubspec.yaml'),
      locator: PubspecLocator.parse(pubspec, 'pubspec.yaml'),
      packageRoot: root ?? temporaryDirectory(),
      lockfile: lock == null
          ? null
          : const LockfileParser().parse(lock, path: 'pubspec.lock'),
      lockLocator: lock == null
          ? null
          : PubspecLocator.parse(lock, 'pubspec.lock'),
      ownsLockfile: owns,
    );
    return DependencyPolicy(
      config: config,
      defaultRegistry: registry,
    ).check(source);
  }

  /// Returns `ruleId package line` of every finding.
  List<String> describe(List<Finding> findings) => <String>[
    for (final finding in findings)
      '${finding.ruleId} ${finding.packageName} ${finding.location?.line}',
  ];

  /// A lockfile entry of [name] [version] from [url].
  String entry(
    String name,
    String version, {
    String dependency = 'direct main',
    String url = 'https://pub.dev',
    String sha = 'aa',
    String source = 'hosted',
  }) =>
      '''
  $name:
    dependency: "$dependency"
    description: {name: $name, sha256: "$sha", url: "$url"}
    source: $source
    version: "$version"
''';

  const app = '''
name: app
environment:
  sdk: ^3.6.0
dependencies:
  http: ^1.2.0
dev_dependencies:
  test: ^1.25.0
''';

  test('a policy without rules finds nothing', () {
    expect(check(const DependencyPolicyConfig(enabled: true), app), isEmpty);
  });

  test('denied packages are reported directly and transitively', () {
    final List<Finding> findings = check(
      const DependencyPolicyConfig(
        denied: <DeniedPackage>[
          DeniedPackage(name: 'http', reason: 'Banned.', replacement: 'dio'),
          DeniedPackage(name: 'left_pad', reason: 'Unmaintained.'),
        ],
      ),
      app,
      lock:
          'packages:\n${entry('http', '1.2.0')}'
          '${entry('left_pad', '1.0.0', dependency: 'transitive')}',
    );
    expect(describe(findings), <String>[
      'DENIED_PACKAGE http 5',
      'DENIED_PACKAGE left_pad 7',
    ]);
    expect(findings.first.description, 'Banned. Use dio instead.');
    expect(findings.last.title, contains('transitive'));
    expect(findings.first.severity, Severity.high);
    expect(findings.first.source, FindingSource.pubspec);
  });

  test('only allowed hosted packages may be declared', () {
    expect(
      describe(
        check(
          const DependencyPolicyConfig(allowed: <String>['test']),
          '$app  local: {path: ../local}\n',
        ),
      ),
      <String>['PACKAGE_NOT_ALLOWED http 5'],
    );
  });

  test('registries and Git hosts must be allowed, direct and locked', () {
    const dartlang = 'https://pub.dartlang.org';
    const corp = 'https://pub.corp';
    final List<Finding> findings = check(
      const DependencyPolicyConfig(
        allowedHosts: <String>['https://pub.corp'],
        allowedGitHosts: <String>['git.corp'],
      ),
      '''
name: app
dependencies:
  http: ^1.2.0
  internal: {hosted: https://pub.corp/, version: ^1.0.0}
  forked: {git: https://github.com/x/forked.git}
  ours: {git: "git@git.corp:team/ours.git"}
''',
      lock:
          'packages:\n${entry('http', '1.2.0')}'
          '${entry('meta', '1.0.0', dependency: 'transitive', url: dartlang)}'
          '${entry('inner', '1.0.0', dependency: 'transitive', url: corp)}',
    );
    expect(describe(findings), <String>[
      'DISALLOWED_HOST http 3',
      'DISALLOWED_HOST forked 5',
      'DISALLOWED_HOST meta 7',
    ]);
    expect(findings[1].title, contains('github.com'));
    expect(
      check(
        const DependencyPolicyConfig(allowedHosts: <String>['https://pub.dev']),
        app,
        registry: 'https://pub.dartlang.org',
      ),
      isEmpty,
    );
    expect(DependencyPolicy.gitHost('git@git.corp:team/x.git'), 'git.corp');
    expect(DependencyPolicy.gitHost('not a url'), 'not a url');
  });

  test('constraints without an upper bound are reported with the fix', () {
    final List<Finding> findings = check(
      const DependencyPolicyConfig(requireUpperBound: true),
      '''
name: app
dependencies:
  http: ">=1.2.0"
  path: {version: ">=1.8.0"}
  meta: any
  flutter: {sdk: flutter}
dev_dependencies:
  test: ">=1.25.0 <2.0.0"
''',
    );
    expect(describe(findings), <String>[
      'MISSING_UPPER_BOUND http 3',
      'MISSING_UPPER_BOUND path 4',
    ]);
    expect(findings.first.attributes['fix'], '^1.2.0');
  });

  test('SDK constraints below the minimum are reported', () {
    final policy = DependencyPolicyConfig(
      minSdk: Version(3, 6, 0),
      minFlutter: Version(3, 27, 0),
    );
    expect(check(policy, app), isEmpty);
    expect(
      describe(
        check(
          policy,
          'name: app\nenvironment:\n  sdk: ">=3.0.0 <4.0.0"\n'
          '  flutter: ">=3.24.0"\ndependencies:\n  flutter: {sdk: flutter}\n',
        ),
      ),
      <String>['SDK_BELOW_POLICY null 3', 'SDK_BELOW_POLICY null 4'],
    );
    expect(describe(check(policy, 'name: app\n')), <String>[
      'SDK_BELOW_POLICY null null',
    ]);
  });

  test('development packages in dependencies are reported', () {
    expect(
      describe(
        check(
          const DependencyPolicyConfig(devOnly: <String>['http', 'test']),
          app,
        ),
      ),
      <String>['DEV_ONLY_DEPENDENCY http 5'],
    );
  });

  test('publish_to and metadata are required as configured', () {
    const policy = DependencyPolicyConfig(
      requirePublishTo: true,
      publishedPackages: <String>['open'],
      requiredMetadata: <String>['description', 'topics', 'repository'],
    );
    expect(describe(check(policy, app)), <String>[
      'MISSING_PUBLISH_TO app 1',
      'MISSING_METADATA app 1',
      'MISSING_METADATA app 1',
      'MISSING_METADATA app 1',
    ]);
    expect(check(policy, 'name: app\npublish_to: none\n'), isEmpty);
    expect(
      describe(
        check(
          policy,
          'name: open\ndescription: D.\nrepository: https://x\n'
          'topics: [a]\n',
        ),
      ),
      isEmpty,
    );
    expect(check(policy, 'description: no name\n'), isEmpty);
  });

  test('a lockfile out of sync with the pubspec is reported', () {
    const policy = DependencyPolicyConfig(lockfileInSync: true);
    final List<Finding> findings = check(
      policy,
      '''
name: app
dependencies:
  http: ^1.2.0
  path: ^1.9.0
  meta: ^1.0.0
dependency_overrides:
  meta: 2.0.0
dev_dependencies:
  test: ^1.25.0
''',
      lock:
          'packages:\n${entry('http', '1.1.0')}${entry('path', '1.9.0')}'
          '${entry('meta', '2.0.0', dependency: 'direct overridden')}'
          '${entry('args', '2.0.0')}',
    );
    expect(describe(findings), <String>[
      'LOCKFILE_OUT_OF_SYNC http 3',
      'LOCKFILE_OUT_OF_SYNC test 9',
      'LOCKFILE_OUT_OF_SYNC args 17',
    ]);
    expect(
      check(
        policy,
        '$app\nworkspace: [pkgs/a]\n',
        lock:
            'packages:\n${entry('http', '1.2.0')}${entry('args', '2.0.0')}'
            '${entry('test', '1.25.0', dependency: 'direct dev')}',
      ),
      isEmpty,
    );
    expect(check(policy, app, lock: 'packages:\n', owns: false), isEmpty);
  });

  test('locked packages without a checksum are reported', () {
    expect(
      describe(
        check(
          const DependencyPolicyConfig(lockfileChecksums: true),
          app,
          lock:
              'packages:\n${entry('http', '1.2.0', sha: '')}'
              '${entry('local', '0.0.1', source: 'path')}',
        ),
      ),
      <String>['MISSING_CHECKSUM http 2'],
    );
  });

  test('imports reveal unused and misplaced dependencies', () {
    final String root = temporaryDirectory();
    writeFile(root, 'lib/a.dart', "import 'package:mockito/mockito.dart';\n");
    writeFile(root, 'test/a.dart', "import 'package:path/path.dart';\n");
    final List<Finding> findings = check(
      const DependencyPolicyConfig(checkImports: true),
      '''
name: app
dependencies:
  http: ^1.2.0
  path: ^1.9.0
  cupertino_icons: ^1.0.0
  flutter: {sdk: flutter}
dev_dependencies:
  mockito: ^5.4.0
''',
      root: root,
    );
    expect(describe(findings), <String>[
      'UNUSED_DEPENDENCY http 3',
      'UNUSED_DEPENDENCY path 4',
      'DEV_DEPENDENCY_IN_LIB mockito 8',
    ]);
    expect(findings[1].description, contains('move it to dev_dependencies'));
  });
}
