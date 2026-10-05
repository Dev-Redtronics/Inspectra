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

import 'dart:io';

import 'package:inspectra/inspectra.dart';
import 'package:test/test.dart';

import '../support/fake_git.dart';
import '../support/fake_process_runner.dart';

/// Tests reading commits and tags through the git command line.
void main() {
  /// Creates a history reading from [git].
  GitHistory history(FakeGit git) =>
      GitHistory(processRunner: git.runner, workingDirectory: '.');

  test('reads the commits of a range with their full messages', () async {
    final git = FakeGit(
      logs: <String, List<GitCommit>>{
        'v1.0.0..HEAD': <GitCommit>[
          GitCommit(hash: hashOf(2), message: 'feat: b\n\nBody\x1fwith US'),
          GitCommit(hash: hashOf(1), message: 'fix: a'),
        ],
      },
    );
    final List<GitCommit> commits = await history(git)
        .commits(to: 'HEAD', from: 'v1.0.0');
    expect(commits.map((commit) => commit.hash), <String>[
      hashOf(2),
      hashOf(1),
    ]);
    expect(commits.first.message, 'feat: b\n\nBody\x1fwith US');
    expect(commits.first.subject, 'feat: b');
    expect(commits.first.shortHash, '2cccccc');
    expect(git.runner.calls.single, startsWith('git -c log.showSignature='));
    expect(
      git.runner.calls.single,
      endsWith('log --no-merges -z --format=%H%x1f%B v1.0.0..HEAD --'),
    );
  });

  test('runs git in the C locale to read untranslated messages', () async {
    final git = FakeGit(empty: true);
    expect(await history(git).hasCommits(), isFalse);
    expect(git.runner.environments.single, <String, String>{
      'LC_ALL': 'C',
      'LANGUAGE': '',
    });
  });

  test('reads every commit without a start', () async {
    final git = FakeGit(
      logs: <String, List<GitCommit>>{'HEAD': const <GitCommit>[]},
    );
    expect(await history(git).commits(to: 'HEAD'), isEmpty);
  });

  test('picks the highest semantic version tag with the prefix', () async {
    final git = FakeGit(
      tags: <String>['v1.2.0', 'v1.10.0', 'v2.0.0-beta.1', 'v1.9', 'x2.0.0'],
    );
    final ReleaseTag? tag = await history(git)
        .latestTag(to: 'HEAD', prefix: 'v');
    expect(tag?.name, 'v2.0.0-beta.1');
    expect(
      (await history(
        FakeGit(tags: <String>['1.0.0', 'release-2.0.0']),
      ).latestTag(to: 'HEAD', prefix: 'release-'))?.name,
      'release-2.0.0',
    );
    expect(await history(FakeGit()).latestTag(to: 'HEAD', prefix: 'v'), isNull);
  });

  test('detects shallow clones', () async {
    expect(await history(FakeGit(shallow: true)).isShallow(), isTrue);
    expect(await history(FakeGit()).isShallow(), isFalse);
  });

  test('rejects revisions that git would read as options', () {
    expect(
      () => history(FakeGit()).commits(to: '--output=x'),
      throwsA(isA<InvalidUsageException>()),
    );
    expect(
      () => history(FakeGit()).latestTag(to: ' ', prefix: 'v'),
      throwsA(isA<InvalidUsageException>()),
    );
  });

  test('maps git failures to exit codes', () async {
    /// Returns the exception of a `git log` failing with [stderr].
    Future<Object?> failure(String stderr) async {
      final git = FakeGit(
        failure: ProcessOutcome(exitCode: 128, stdout: '', stderr: stderr),
      );
      try {
        await history(git).commits(to: 'HEAD');
      } on InspectraException catch (error) {
        return error;
      }
      return null;
    }

    expect(
      await failure('fatal: not a git repository (or any parent)'),
      isA<InvalidUsageException>().having(
        (error) => error.message,
        'message',
        contains('No Git repository found'),
      ),
    );
    expect(
      await failure("fatal: bad revision 'v9..HEAD'"),
      isA<InvalidUsageException>().having(
        (error) => error.message,
        'message',
        "Git cannot resolve the range: fatal: bad revision 'v9..HEAD'",
      ),
    );
    expect(
      await failure('fatal: detected dubious ownership\nmore'),
      isA<UnavailableException>().having(
        (error) => error.message,
        'message',
        'git log failed with exit code 128: fatal: detected dubious '
            'ownership',
      ),
    );
  });

  test('reports a missing git as unavailable', () {
    final runner = FakeProcessRunner(
      (executable, arguments) => throw const ProcessException('git', []),
    );
    expect(
      GitHistory(processRunner: runner, workingDirectory: '.').isShallow(),
      throwsA(isA<UnavailableException>()),
    );
  });

  test('reads a file as it was at a revision', () async {
    final git = FakeGit(
      tags: <String>['v1.0.0'],
      files: <String, String>{'v1.0.0:api/app.api': 'library a\n'},
    );
    expect(await history(git).show('v1.0.0', r'api\app.api'), 'library a\n');
    expect(git.runner.calls.single, endsWith('show v1.0.0:./api/app.api'));
    expect(await history(git).show('v1.0.0', 'api/other.api'), isNull);
    expect(
      history(git).show('v2.0.0', 'api/app.api'),
      throwsA(isA<InvalidUsageException>()),
    );
    expect(
      history(FakeGit(failure: _failed('fatal: out of memory')))
          .show('v1.0.0', 'api/app.api'),
      throwsA(isA<UnavailableException>()),
    );
  });

  test('tells whether the repository has a commit', () async {
    expect(await history(FakeGit()).hasCommits(), isTrue);
    expect(await history(FakeGit(empty: true)).hasCommits(), isFalse);
    expect(
      history(FakeGit(failure: _failed('fatal: out of memory'))).hasCommits(),
      throwsA(isA<UnavailableException>()),
    );
  });
}

/// Returns a failed `git` call that reports [error].
ProcessOutcome _failed(String error) =>
    ProcessOutcome(exitCode: 128, stdout: '', stderr: error);
