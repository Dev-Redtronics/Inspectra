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

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/changelog/git_commit.dart';
import 'package:test/test.dart';

import '../support/fake_git.dart';
import '../support/fake_process_runner.dart';
import '../support/test_harness.dart';

/// Runs the changelog commands in-process against a scripted git.
void main() {
  final harnesses = <TestHarness>[];

  tearDown(() {
    for (final harness in harnesses) {
      harness.dispose();
    }
    harnesses.clear();
  });

  const pubspec = '''
name: demo
version: 1.1.0
repository: https://github.com/acme/demo
''';

  const changelog = '''
# Changelog

## 1.0.0 - 2026-01-01

- First release.
''';

  /// The history of the demo package: one release and three commits.
  FakeGit history({bool shallow = false}) => FakeGit(
    tags: <String>['v1.0.0'],
    shallow: shallow,
    logs: <String, List<GitCommit>>{
      'v1.0.0..HEAD': <GitCommit>[
        GitCommit(hash: hashOf(3), message: 'feat(cli): add --json'),
        GitCommit(hash: hashOf(2), message: 'fix: handle empty files'),
        GitCommit(hash: hashOf(1), message: 'chore: tidy up'),
      ],
      'v1.0.0..v1.0.0': const <GitCommit>[],
    },
  );

  /// Creates a project with [files] whose git is [git].
  TestHarness project(
    Map<String, String> files, {
    ProcessRunner? processRunner,
  }) {
    final harness = TestHarness.withFiles(
      files,
      processRunner: processRunner ?? history().runner,
    );
    harnesses.add(harness);
    return harness;
  }

  group('changelog generate', () {
    test('prints the next release as Markdown', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.yaml': pubspec,
      });
      expect(await harness.run(<String>['changelog', 'generate']), 0);
      expect(
        harness.out,
        startsWith(
          '## 1.1.0 - 2026-10-01\n\n### Added\n\n- **cli:** add --json '
          '([`3cccccc`](https://github.com/acme/demo/commit/${hashOf(3)}))',
        ),
      );
      expect(harness.out, contains('### Fixed\n\n- handle empty files'));
      expect(harness.out, isNot(contains('tidy up')));
      expect(harness.out, endsWith('/compare/v1.0.0...v1.1.0)\n'));
      expect(
        harness.err,
        contains('Version 1.1.0: 2 changes since v1.0.0, a minor release.'),
      );
    });

    test('reports the release as JSON', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.yaml': pubspec,
      });
      final int code = await harness.run(<String>[
        'changelog',
        'generate',
        '--format',
        'json',
        '--release',
        '2.0.0',
        '--date',
        '2026-10-04',
      ]);
      expect(code, 0);
      final json = jsonDecode(harness.out) as Map<String, Object?>;
      expect(json['command'], 'changelog generate');
      expect(json['version'], '2.0.0');
      expect(json['tag'], 'v2.0.0');
      expect(json['previous_tag'], 'v1.0.0');
      expect(json['bump'], 'minor');
      expect(json['date'], '2026-10-04');
      expect(json['written'], isNull);
      expect(json['markdown'], startsWith('## 2.0.0 - 2026-10-04'));
      final changes = json['changes']! as Map<String, Object?>;
      final sections = changes['sections']! as Map<String, Object?>;
      expect(sections.keys, <String>['added', 'fixed']);
      expect(json['findings'], isEmpty);
      expect(
        harness.err,
        contains(
          'pubspec.yaml declares version 1.1.0; set it to 2.0.0 before '
          'tagging v2.0.0.',
        ),
      );
    });

    test('adds the release to the changelog once', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.yaml': pubspec,
        'CHANGELOG.md': changelog,
      });
      expect(
        await harness.run(<String>['changelog', 'generate', '--write']),
        0,
      );
      expect(
        harness.out,
        contains('Version 1.1.0 added to CHANGELOG.md (2 changes).'),
      );
      final String written = File('${harness.workingDirectory}/CHANGELOG.md')
          .readAsStringSync();
      expect(written, startsWith('# Changelog\n\n## 1.1.0 - 2026-10-01\n'));
      expect(written, endsWith('## 1.0.0 - 2026-01-01\n\n- First release.\n'));
      expect(await harness.run(<String>['changelog', 'check']), 0);
      expect(
        await harness.run(<String>['changelog', 'generate', '--write']),
        64,
      );
      expect(harness.err, contains('already has a section for version 1.1.0'));
    });

    test('writes nothing when there is nothing to release', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.yaml': pubspec,
        'CHANGELOG.md': changelog,
      });
      final int code = await harness.run(<String>[
        'changelog',
        'generate',
        '--to',
        'v1.0.0',
        '--write',
      ]);
      expect(code, 0);
      expect(harness.out, 'No changes to release since v1.0.0.\n');
      expect(
        File('${harness.workingDirectory}/CHANGELOG.md').readAsStringSync(),
        changelog,
      );
    });

    test('warns about shallow clones', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.yaml': pubspec,
      }, processRunner: history(shallow: true).runner);
      expect(await harness.run(<String>['changelog', 'generate']), 0);
      expect(harness.err, contains('warning: The repository is a shallow'));
    });

    test('exits with 64 for invalid input and outside a repository', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.yaml': pubspec,
      });
      expect(
        await harness.run(<String>['changelog', 'generate', '--date', 'x']),
        64,
      );
      expect(
        await harness.run(<String>['changelog', 'generate', '--from', 'v9']),
        64,
      );
      expect(harness.err, contains('Git cannot resolve the range'));
      final TestHarness outside = project(
        <String, String>{'pubspec.yaml': pubspec},
        processRunner: FakeGit(
          failure: const ProcessOutcome(
            exitCode: 128,
            stdout: '',
            stderr: 'fatal: not a git repository',
          ),
        ).runner,
      );
      expect(await outside.run(<String>['changelog', 'generate']), 64);
      expect(outside.err, contains('No Git repository found'));
    });

    test('exits with 69 without git', () async {
      final TestHarness harness = project(
        <String, String>{'pubspec.yaml': pubspec},
        processRunner: FakeProcessRunner(
          (executable, arguments) => throw const ProcessException('git', []),
        ),
      );
      expect(await harness.run(<String>['changelog', 'generate']), 69);
    });
  });

  group('changelog check', () {
    test('fails when the package version is not documented', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.yaml': pubspec,
        'CHANGELOG.md': changelog,
      });
      expect(await harness.run(<String>['changelog', 'check']), 1);
      expect(harness.out, contains('Version 1.1.0 of pubspec.yaml'));
    });

    test('runs as part of check when enabled', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.yaml':
            '${pubspec}inspectra:\n  changelog:\n    enabled: true\n',
        'CHANGELOG.md': '## 1.1.0\n\n- Next.\n\n$changelog',
      });
      expect(await harness.run(<String>['check']), 0);
      expect(
        harness.out,
        contains('CHANGELOG.md is well-formed and documents version 1.1.0.'),
      );
    });

    test('exits with 65 for a malformed pubspec.yaml', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.yaml': 'name: demo\nversion: [',
        'CHANGELOG.md': changelog,
      });
      expect(await harness.run(<String>['changelog', 'check']), 65);
    });
  });

  group('changelog notes', () {
    test('prints the section of a release', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.yaml': pubspec,
        'CHANGELOG.md': changelog,
      });
      expect(await harness.run(<String>['changelog', 'notes', '1.0.0']), 0);
      expect(harness.out, '- First release.\n');
      final int code = await harness.run(<String>[
        'changelog',
        'notes',
        'v1.0.0',
        '--format',
        'json',
        '--output',
        'notes.json',
      ]);
      expect(code, 0);
      final json = jsonDecode(
        File('${harness.workingDirectory}/notes.json').readAsStringSync(),
      ) as Map<String, Object?>;
      expect(json['version'], '1.0.0');
      expect(json['date'], '2026-01-01');
      expect(json['notes'], '- First release.');
    });

    test('defaults to the version of pubspec.yaml', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.yaml': pubspec,
        'CHANGELOG.md': '## 1.1.0\n\n- Next.\n\n$changelog',
      });
      expect(await harness.run(<String>['changelog', 'notes']), 0);
      expect(harness.out, '- Next.\n');
    });

    test('exits with 65 for undocumented versions', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.yaml': pubspec,
        'CHANGELOG.md': '## 1.1.0\n\n## 1.0.0\n\n- x\n',
      });
      expect(await harness.run(<String>['changelog', 'notes', '2.0.0']), 65);
      expect(harness.err, contains('has no section for version 2.0.0'));
      expect(await harness.run(<String>['changelog', 'notes']), 65);
      expect(harness.err, contains('is empty'));
      File('${harness.workingDirectory}/CHANGELOG.md').deleteSync();
      expect(await harness.run(<String>['changelog', 'notes']), 65);
      expect(harness.err, contains('does not exist'));
    });

    test('exits with 64 without any version', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.yaml': 'name: demo\n',
        'CHANGELOG.md': changelog,
      });
      expect(await harness.run(<String>['changelog', 'notes']), 64);
    });
  });
}
