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

import 'package:inspectra/src/changelog/git_commit.dart';
import 'package:inspectra/src/changelog/release_tag.dart';
import 'package:inspectra/src/io/process_outcome.dart';
import 'package:inspectra/src/io/process_runner.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';

/// Reads commits and release tags with the `git` command line.
///
/// Every call disables the settings that would change the output Inspectra
/// parses: signature verification in `git log`, colours and the log
/// encoding.
final class GitHistory {
  /// Creates a reader for the repository containing [workingDirectory].
  const GitHistory({
    required this.processRunner,
    required this.workingDirectory,
  });

  /// Runs `git`.
  final ProcessRunner processRunner;

  /// A directory inside the Git repository.
  final String workingDirectory;

  /// The options given to every `git` call.
  static const _settings = <String>[
    '-c',
    'log.showSignature=false',
    '-c',
    'i18n.logOutputEncoding=UTF-8',
    '-c',
    'color.ui=false',
  ];

  /// Separates the hash from the message of a commit in `git log` output.
  static const _fieldSeparator = '\u001f';

  /// Reads the commits reachable from [to] but not from [from], newest
  /// first, without merge commits; every commit reachable from [to] when
  /// [from] is `null`.
  ///
  /// Returns the commits.
  ///
  /// Throws an [InvalidUsageException] outside of a Git repository or for
  /// a revision Git cannot resolve, and an [UnavailableException] when Git
  /// is not installed or fails otherwise.
  Future<List<GitCommit>> commits({required String to, String? from}) async {
    final String range = from == null
        ? _revision(to)
        : '${_revision(from)}..${_revision(to)}';
    final String output = await _git(<String>[
      'log',
      '--no-merges',
      '-z',
      '--format=%H%x1f%B',
      range,
      '--',
    ]);
    final commits = <GitCommit>[];
    for (final String record in output.split('\u0000')) {
      final int separator = record.indexOf(_fieldSeparator);
      if (separator < 0) {
        continue;
      }
      commits.add(
        GitCommit(
          hash: record.substring(0, separator).trim(),
          message: record.substring(separator + 1).trimRight(),
        ),
      );
    }
    return List<GitCommit>.unmodifiable(commits);
  }

  /// Finds the release tag with the highest version among the tags that
  /// start with [prefix] and are reachable from [to].
  ///
  /// Returns the tag, or `null` when there is none.
  ///
  /// Throws an [InvalidUsageException] outside of a Git repository or for
  /// a revision Git cannot resolve, and an [UnavailableException] when Git
  /// is not installed or fails otherwise.
  Future<ReleaseTag?> latestTag({
    required String to,
    required String prefix,
  }) async {
    final String output = await _git(<String>[
      'tag',
      '--list',
      '--merged',
      _revision(to),
    ]);
    ReleaseTag? latest;
    for (final String line in output.split('\n')) {
      final ReleaseTag? tag = ReleaseTag.tryParse(line.trim(), prefix);
      final current = latest;
      final bool higher =
          tag != null && (current == null || tag.version > current.version);
      if (higher) {
        latest = tag;
      }
    }
    return latest;
  }

  /// Whether the repository is a shallow clone, whose history and tags may
  /// be incomplete.
  ///
  /// Returns `true` for a shallow clone.
  ///
  /// Throws an [InvalidUsageException] outside of a Git repository and an
  /// [UnavailableException] when Git is not installed or fails otherwise.
  Future<bool> isShallow() async {
    final String output = await _git(const <String>[
      'rev-parse',
      '--is-shallow-repository',
    ]);
    return output.trim() == 'true';
  }

  /// Validates the revision [revision] given by the user.
  ///
  /// Returns the revision.
  ///
  /// Throws an [InvalidUsageException] for an empty revision or one that
  /// Git would read as an option.
  String _revision(String revision) {
    final String trimmed = revision.trim();
    if (trimmed.isEmpty || trimmed.startsWith('-')) {
      throw InvalidUsageException('"$revision" is not a Git revision.');
    }
    return trimmed;
  }

  /// Runs `git` with [arguments].
  ///
  /// Returns the standard output.
  ///
  /// Throws an [InvalidUsageException] outside of a Git repository or for
  /// a revision Git cannot resolve, and an [UnavailableException] when Git
  /// is not installed or fails otherwise.
  Future<String> _git(List<String> arguments) async {
    final ProcessOutcome result;
    try {
      result = await processRunner.run('git', <String>[
        ..._settings,
        ...arguments,
      ], workingDirectory: workingDirectory);
    } on ProcessException {
      throw const UnavailableException(
        'Git is not installed or not on the PATH.',
      );
    }
    if (result.succeeded) {
      return result.stdout;
    }
    final String error = result.stderr.trim();
    final String lower = error.toLowerCase();
    if (lower.contains('not a git repository')) {
      throw const InvalidUsageException(
        'No Git repository found. Run this command inside a Git repository.',
      );
    }
    const unresolved = <String>[
      'unknown revision',
      'bad revision',
      'ambiguous argument',
      'malformed object name',
      'does not have any commits',
      'no such commit',
    ];
    final String firstLine = error.split('\n').first;
    if (unresolved.any(lower.contains)) {
      throw InvalidUsageException('Git cannot resolve the range: $firstLine');
    }
    throw UnavailableException(
      'git ${arguments.first} failed with exit code ${result.exitCode}: '
      '$firstLine',
    );
  }
}
