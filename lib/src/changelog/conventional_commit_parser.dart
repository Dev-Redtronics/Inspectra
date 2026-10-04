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
import 'package:inspectra/src/changelog/git_commit.dart';

/// Parses commit messages according to
/// [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).
///
/// The header is `type(scope)!: description`, where the scope and the `!`
/// are optional. A breaking change is marked with `!` or with a
/// `BREAKING CHANGE:` (or `BREAKING-CHANGE:`) footer, whose text may span
/// several lines up to the next footer. The `Revert "..."` messages written
/// by `git revert` are understood as the type `revert`.
final class ConventionalCommitParser {
  /// Creates a parser.
  const ConventionalCommitParser();

  /// Matches the header line `type(scope)!: description`.
  static final _header = RegExp(
    r'^([A-Za-z][A-Za-z0-9-]*)(?:\(([^()\r\n]+)\))?(!)?: (\S.*)$',
  );

  /// Matches the subject `git revert` writes, `Revert "subject"`.
  static final _gitRevert = RegExp(r'^Revert "(.+)"$');

  /// Matches the line `git revert` writes into the body.
  static final _revertedCommit = RegExp(
    'This reverts commit ([0-9a-fA-F]{7,64})',
  );

  /// Matches a breaking change footer and captures its first line.
  static final _breakingFooter = RegExp(r'^BREAKING[ -]CHANGE: ?(.*)$');

  /// Matches the start of any footer, `Token: value` or `Token #value`.
  static final _footer = RegExp(
    '^(?:BREAKING[ -]CHANGE|[A-Za-z][A-Za-z0-9-]*)(?:: | #)',
  );

  /// Parses [commit].
  ///
  /// Returns the parsed commit; a commit that does not follow the
  /// convention has the type `null` and its subject as description.
  ConventionalCommit parse(GitCommit commit) {
    final List<String> lines = commit.message
        .replaceAll('\r\n', '\n')
        .split('\n');
    final String subject = lines.first.trim();
    final List<String> body = lines.skip(1).toList();
    final List<String> notes = _breakingNotes(body);
    final reverted = <String>[
      for (final RegExpMatch match in _revertedCommit.allMatches(
        body.join('\n'),
      ))
        (match[1] ?? '').toLowerCase(),
    ];
    final RegExpMatch? revert = _gitRevert.firstMatch(subject);
    if (revert != null) {
      return _revertOf(commit.hash, revert[1] ?? '', notes, reverted);
    }
    final RegExpMatch? header = _header.firstMatch(subject);
    if (header == null) {
      return ConventionalCommit(
        hash: commit.hash,
        type: null,
        description: subject,
        revertedHashes: reverted,
      );
    }
    return ConventionalCommit(
      hash: commit.hash,
      type: (header[1] ?? '').toLowerCase(),
      scope: header[2]?.trim(),
      description: (header[4] ?? '').trim(),
      breaking: header[3] != null || notes.isNotEmpty,
      breakingNotes: notes,
      revertedHashes: reverted,
    );
  }

  /// Describes a `git revert` commit of the commit whose subject was
  /// [revertedSubject].
  ///
  /// Returns a commit of the type `revert` that keeps the scope of the
  /// reverted commit.
  ConventionalCommit _revertOf(
    String hash,
    String revertedSubject,
    List<String> notes,
    List<String> reverted,
  ) {
    final RegExpMatch? inner = _header.firstMatch(revertedSubject);
    final String description = inner == null
        ? revertedSubject
        : (inner[4] ?? '').trim();
    return ConventionalCommit(
      hash: hash,
      type: 'revert',
      scope: inner?[2]?.trim(),
      description: 'Revert "$description"',
      breaking: notes.isNotEmpty,
      breakingNotes: notes,
      revertedHashes: reverted,
    );
  }

  /// Collects the text of every breaking change footer in [body].
  ///
  /// A footer continues on the following lines until the next footer or
  /// the end of the message.
  ///
  /// Returns the footer texts, without empty ones.
  List<String> _breakingNotes(List<String> body) {
    final notes = <String>[];
    StringBuffer? current;
    for (final line in body) {
      final RegExpMatch? breaking = _breakingFooter.firstMatch(line);
      if (breaking != null) {
        _addNote(notes, current);
        current = StringBuffer(breaking[1] ?? '');
        continue;
      }
      if (_footer.hasMatch(line)) {
        _addNote(notes, current);
        current = null;
        continue;
      }
      current?.write('\n$line');
    }
    _addNote(notes, current);
    return List<String>.unmodifiable(notes);
  }

  /// Adds the trimmed text of [note] to [notes] unless it is empty.
  void _addNote(List<String> notes, StringBuffer? note) {
    final String text = note?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      notes.add(text);
    }
  }
}
