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
import 'package:inspectra/src/deps/outdated_outcome.dart';
import 'package:inspectra/src/deps/outdated_policy.dart';
import 'package:inspectra/src/deps/policy_source.dart';
import 'package:inspectra/src/pub/lockfile_parser.dart';
import 'package:inspectra/src/pub/pub_package.dart';
import 'package:inspectra/src/pub/pub_version.dart';
import 'package:inspectra/src/pub/pubspec_locator.dart';
import 'package:inspectra/src/pub/pubspec_parser.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

/// Tests how far the dependencies are behind the registry.
void main() {
  const pubspec = '''
name: app
dependencies:
  path: ^1.0.0
  http: ^1.0.0
dev_dependencies:
  lints: ^4.0.0
''';

  /// A lockfile entry of [name] [version] that is [dependency].
  String entry(String name, String version, String dependency) =>
      '''
  $name:
    dependency: "$dependency"
    description: {name: $name, sha256: "aa", url: "https://pub.dev"}
    source: hosted
    version: "$version"
''';

  final lock =
      'packages:\n${entry('path', '1.0.0', 'direct main')}'
      '${entry('http', '1.2.0', 'direct main')}'
      '${entry('lints', '4.0.0', 'direct dev')}'
      '${entry('meta', '1.0.0', 'transitive')}';

  /// Builds a listing of [name] with [versions] published on the dates.
  PubPackage listing(String name, Map<String, String> versions) => PubPackage(
    name: name,
    latestVersion: versions.keys.last,
    versions: <PubVersion>[
      for (final MapEntry(key: version, value: date) in versions.entries)
        PubVersion(version: version, published: DateTime.parse(date)),
    ],
  );

  final listings = <String, PubPackage>{
    'path': listing('path', <String, String>{
      '1.0.0': '2024-01-01',
      '2.0.0': '2024-06-01',
      '3.0.0': '2025-01-01',
      '3.1.0': '2026-01-01',
    }),
    'http': listing('http', <String, String>{
      '1.2.0': '2025-06-01',
      '1.3.0': '2025-12-01',
    }),
    'lints': listing('lints', <String, String>{
      '4.0.0': '2024-01-01',
      '5.0.0': '2024-02-01',
      '6.0.0': '2025-01-01',
    }),
    'meta': listing('meta', <String, String>{
      '1.0.0': '2020-01-01',
      '1.17.0': '2026-01-01',
    }),
  };

  /// Checks the test package with [config], recording the lookups in
  /// [asked].
  ///
  /// Returns the outcome.
  Future<OutdatedOutcome> check(
    DependencyPolicyConfig config, {
    List<String>? asked,
    bool withLock = true,
  }) =>
      OutdatedPolicy(
        config: config,
        defaultRegistry: 'https://pub.dev',
        lookup: (name, registry) async {
          asked?.add('$registry $name');
          return listings[name];
        },
      ).check(
        PolicySource(
          pubspec: const PubspecParser().parse(pubspec, path: 'pubspec.yaml'),
          locator: PubspecLocator.parse(pubspec, 'pubspec.yaml'),
          packageRoot: '.',
          lockfile: withLock
              ? const LockfileParser().parse(lock, path: 'pubspec.lock')
              : null,
          ownsLockfile: true,
        ),
      );

  test(
    'reports direct dependencies too many breaking releases behind',
    () async {
      final asked = <String>[];
      final OutdatedOutcome outcome = await check(
        const DependencyPolicyConfig(maxMajorBehind: 1),
        asked: asked,
      );
      expect(asked, <String>[
        'https://pub.dev http',
        'https://pub.dev lints',
        'https://pub.dev path',
      ]);
      expect(
        outcome.findings.map(
          (finding) =>
              '${finding.ruleId} ${finding.packageName} '
              '${finding.location?.line} ${finding.attributes['behind']}',
        ),
        <String>['OUTDATED_MAJOR lints 6 2', 'OUTDATED_MAJOR path 3 2'],
      );
      final Finding path = outcome.findings.last;
      expect(path.packageVersion, '1.0.0');
      expect(path.fixedVersion, '3.1.0');
      expect(path.severity, Severity.medium);
      expect(
        path.title,
        'path is 2 breaking release(s) behind (1.0.0, latest 3.1.0)',
      );
      expect(
        (await check(const DependencyPolicyConfig(maxMajorBehind: 2))).findings,
        isEmpty,
      );
    },
  );

  test('adds up libyears of the direct or of every dependency', () async {
    final OutdatedOutcome direct = await check(
      const DependencyPolicyConfig(maxLibyear: 3),
    );
    expect(direct.libyears, closeTo(2.0 + 0.5 + 1.0, 0.02));
    expect(direct.findings.single.ruleId, 'LIBYEAR_EXCEEDED');
    expect(direct.findings.single.location?.line, 1);
    expect(
      direct.findings.single.description,
      contains('path (2.0), lints (1.0), http (0.5)'),
    );
    final OutdatedOutcome all = await check(
      const DependencyPolicyConfig(
        maxLibyear: 10,
        libyearScope: LibyearScope.all,
      ),
    );
    expect(all.libyears, closeTo(9.5, 0.02));
    expect(all.findings, isEmpty);
  });

  test('checks nothing without rules or lockfile', () async {
    final OutdatedOutcome none = await check(const DependencyPolicyConfig());
    expect(none.findings, isEmpty);
    expect(none.libyears, isNull);
    final OutdatedOutcome noLock = await check(
      const DependencyPolicyConfig(maxMajorBehind: 0),
      withLock: false,
    );
    expect(noLock.libyears, isNull);
  });

  test('counts breaking release lines, before 1.0.0 by minor', () {
    /// Lists [versions] as published.
    List<PubVersion> published(List<String> versions) => <PubVersion>[
      for (final version in versions) PubVersion(version: version),
    ];

    expect(
      breakingReleasesBetween(
        Version.parse('0.3.1'),
        Version.parse('1.1.0'),
        <PubVersion>[
          ...published(<String>['0.3.2', '0.4.0', '0.5.0', '1.0.0', '1.1.0']),
          const PubVersion(version: '0.6.0', retracted: true),
          const PubVersion(version: '2.0.0-dev.1'),
        ],
      ),
      3,
    );
    expect(
      breakingReleasesBetween(
        Version.parse('2.0.0'),
        Version.parse('2.3.0'),
        published(<String>['2.1.0', '2.3.0']),
      ),
      0,
    );
  });
}
