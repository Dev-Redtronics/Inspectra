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

import 'package:inspectra/src/changelog/conventional_commit.dart';
import 'package:inspectra/src/changelog/conventional_commit_parser.dart';
import 'package:inspectra/src/changelog/git_commit.dart';
import 'package:test/test.dart';

import '../support/fake_git.dart';

/// Tests parsing commit messages according to Conventional Commits.
void main() {
  const parser = ConventionalCommitParser();

  /// Parses [message] as the message of a commit.
  ConventionalCommit parse(String message) =>
      parser.parse(GitCommit(hash: hashOf(1), message: message));

  test('parses type, scope and description', () {
    final ConventionalCommit commit = parse('feat(trivy): scan images');
    expect(commit.isConventional, isTrue);
    expect(commit.type, 'feat');
    expect(commit.scope, 'trivy');
    expect(commit.description, 'scan images');
    expect(commit.breaking, isFalse);
    expect(commit.shortHash, hashOf(1).substring(0, 7));
  });

  test('accepts headers without scope and normalises the type', () {
    final ConventionalCommit commit = parse('FIX: handle empty lockfiles');
    expect(commit.type, 'fix');
    expect(commit.scope, isNull);
    expect(commit.description, 'handle empty lockfiles');
  });

  test('marks breaking changes with an exclamation mark', () {
    expect(parse('feat!: drop Dart 2').breaking, isTrue);
    expect(parse('refactor(cli)!: rename --out').breaking, isTrue);
  });

  test('reads multi-line BREAKING CHANGE and BREAKING-CHANGE footers', () {
    final ConventionalCommit commit = parse(
      'feat(api): new dump format\n'
      '\n'
      'The dump now records constants.\n'
      '\n'
      'BREAKING CHANGE: the dump must be recorded again\n'
      'with inspectra api dump.\n'
      'Refs: #12\n'
      'BREAKING-CHANGE: older dumps are rejected\n',
    );
    expect(commit.breaking, isTrue);
    expect(commit.breakingNotes, <String>[
      'the dump must be recorded again\nwith inspectra api dump.',
      'older dumps are rejected',
    ]);
  });

  test('ignores empty breaking footers and lower case look-alikes', () {
    final ConventionalCommit commit = parse(
      'fix: x\n\nbreaking change: not a footer\nBREAKING CHANGE:\n',
    );
    expect(commit.breaking, isFalse);
    expect(commit.breakingNotes, isEmpty);
  });

  test('understands CRLF line endings', () {
    final ConventionalCommit commit = parse(
      'fix: x\r\n\r\nBREAKING CHANGE: y\r\n',
    );
    expect(commit.breakingNotes, <String>['y']);
  });

  test('treats other subjects as unconventional', () {
    for (final subject in <String>[
      'Update README',
      'feat:missing space',
      'feat(): empty scope',
      'fixup! feat: x',
      ': no type',
    ]) {
      final ConventionalCommit commit = parse(subject);
      expect(commit.isConventional, isFalse, reason: subject);
      expect(commit.description, subject);
    }
  });

  test('understands the messages of git revert', () {
    final ConventionalCommit commit = parse(
      'Revert "feat(trivy): scan images"\n'
      '\n'
      'This reverts commit ${hashOf(7).toUpperCase()}.\n',
    );
    expect(commit.type, 'revert');
    expect(commit.scope, 'trivy');
    expect(commit.description, 'Revert "scan images"');
    expect(commit.revertedHashes, <String>[hashOf(7)]);
    final ConventionalCommit plain = parse('Revert "Update README"');
    expect(plain.scope, isNull);
    expect(plain.description, 'Revert "Update README"');
  });

  test('keeps the reverted commits of conventional reverts', () {
    final ConventionalCommit commit = parse(
      'revert: undo the cache\n\nThis reverts commit abcdef1.',
    );
    expect(commit.type, 'revert');
    expect(commit.revertedHashes, <String>['abcdef1']);
  });
}
