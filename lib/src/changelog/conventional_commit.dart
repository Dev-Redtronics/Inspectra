/*
 * Copyright 2026 Redtronics
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

/// A commit message that follows
/// [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/),
/// or a commit that does not, described by its subject.
final class ConventionalCommit {
  /// Creates a parsed commit.
  ///
  /// [type] is `null` for a commit that does not follow the convention;
  /// its [description] is then the subject line.
  const ConventionalCommit({
    required this.hash,
    required this.type,
    required this.description,
    this.scope,
    this.breaking = false,
    this.breakingNotes = const <String>[],
    this.revertedHashes = const <String>[],
  });

  /// The full object name of the commit.
  final String hash;

  /// The lower case type, such as `feat` or `fix`, or `null` for a commit
  /// that does not follow the convention.
  final String? type;

  /// The scope in parentheses after the type, if any.
  final String? scope;

  /// The description after the colon.
  final String description;

  /// Whether the commit is marked as a breaking change, with `!` after the
  /// type or scope or with a `BREAKING CHANGE` footer.
  final bool breaking;

  /// The texts of the `BREAKING CHANGE` and `BREAKING-CHANGE` footers.
  final List<String> breakingNotes;

  /// The object names of the commits this commit reverts, taken from the
  /// `This reverts commit <hash>.` line that `git revert` writes.
  final List<String> revertedHashes;

  /// Whether the commit follows Conventional Commits.
  bool get isConventional => type != null;

  /// The abbreviated object name shown in changelogs.
  String get shortHash => hash.length > 7 ? hash.substring(0, 7) : hash;
}
