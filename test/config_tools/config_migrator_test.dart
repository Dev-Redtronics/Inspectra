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
import 'package:inspectra/src/config_tools/config_migration.dart';
import 'package:inspectra/src/config_tools/config_migrator.dart';
import 'package:test/test.dart';

/// Tests replacing the old names of renamed options in a file.
void main() {
  const renames = <ConfigDeprecation>[
    ConfigDeprecation(
      oldPath: 'trivy.secrets',
      newPath: 'trivy.secret',
      since: '1.1.0',
    ),
    ConfigDeprecation(
      oldPath: 'fail_level',
      newPath: 'fail_on',
      since: '1.1.0',
    ),
  ];

  test('renames keys only, in the file and its profiles', () {
    const content =
        '# Our configuration\n'
        'fail_level: high # keep failing on high\n'
        'trivy:\n'
        '  secrets:\n'
        '    enabled: true\n'
        'profiles:\n'
        '  ci:\n'
        '    fail_level: low\n';
    final ConfigMigration migration = migrateConfig(
      content,
      label: 'inspectra.yaml',
      deprecations: renames,
    );
    expect(
      migration.content,
      '# Our configuration\n'
      'fail_on: high # keep failing on high\n'
      'trivy:\n'
      '  secret:\n'
      '    enabled: true\n'
      'profiles:\n'
      '  ci:\n'
      '    fail_on: low\n',
    );
    expect(
      migration.renamed.map((option) => '${option.path}:${option.line}'),
      <String>['fail_level:2', 'trivy.secrets:4', 'profiles.ci.fail_level:8'],
    );
    expect(migration.changed, isTrue);
  });

  test('migrates the section of pubspec.yaml and leaves the rest', () {
    const content =
        'name: demo\n'
        'fail_level: kept\n'
        'inspectra:\n'
        '  fail_level: high\n';
    final ConfigMigration migration = migrateConfig(
      content,
      label: 'pubspec.yaml',
      root: const <String>['inspectra'],
      deprecations: renames,
    );
    expect(
      migration.content,
      'name: demo\nfail_level: kept\ninspectra:\n  fail_on: high\n',
    );
    expect(migration.renamed.single.path, 'inspectra.fail_level');
  });

  test('changes nothing without old names and rejects both names', () {
    final ConfigMigration none = migrateConfig(
      'fail_on: high\n',
      label: 'inspectra.yaml',
      deprecations: renames,
    );
    expect(none.changed, isFalse);
    expect(none.content, 'fail_on: high\n');
    expect(
      () => migrateConfig(
        'fail_level: high\nfail_on: low\n',
        label: 'inspectra.yaml',
        deprecations: renames,
      ),
      throwsA(
        isA<InspectraConfigException>().having(
          (error) => '$error',
          'message',
          contains('"fail_level" in inspectra.yaml'),
        ),
      ),
    );
    expect(
      () => migrateConfig('a: [', label: 'inspectra.yaml'),
      throwsA(isA<InspectraConfigException>()),
    );
  });
}
