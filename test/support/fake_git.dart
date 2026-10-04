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

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/changelog/git_commit.dart';

import 'fake_process_runner.dart';

/// Returns a 40 character object name derived from [seed].
String hashOf(int seed) => seed.toRadixString(16).padRight(40, 'c');

/// A scripted `git` for the changelog commands: it answers `log`, `tag`
/// and `rev-parse` from fixed data.
final class FakeGit {
  /// Creates a repository whose `git log <range>` answers [logs] by range,
  /// whose tags are [tags] and that is a shallow clone when [shallow] is
  /// `true`; [failure], when given, answers every call.
  FakeGit({
    this.logs = const <String, List<GitCommit>>{},
    this.tags = const <String>[],
    this.shallow = false,
    this.failure,
  });

  /// The commits returned by `git log`, keyed by the requested range.
  final Map<String, List<GitCommit>> logs;

  /// The tags reachable from every revision.
  final List<String> tags;

  /// Whether the repository is a shallow clone.
  final bool shallow;

  /// The outcome of every call, to simulate failures.
  final ProcessOutcome? failure;

  /// The process runner answering the calls.
  late final runner = FakeProcessRunner(_answer);

  /// Answers one call of [executable] with [arguments].
  ///
  /// Returns the scripted outcome.
  ProcessOutcome _answer(String executable, List<String> arguments) {
    final ProcessOutcome? failed = failure;
    if (failed != null) {
      return failed;
    }
    final command = <String>[
      for (var index = 0; index < arguments.length; index++)
        if (arguments[index] != '-c' &&
            (index == 0 || arguments[index - 1] != '-c'))
          arguments[index],
    ];
    final String name = command.first;
    if (name == 'rev-parse') {
      return ProcessOutcome(exitCode: 0, stdout: '$shallow\n', stderr: '');
    }
    if (name == 'tag') {
      return ProcessOutcome(
        exitCode: 0,
        stdout: tags.map((tag) => '$tag\n').join(),
        stderr: '',
      );
    }
    final String range = command[command.length - 2];
    final List<GitCommit>? commits = logs[range];
    if (commits == null) {
      return ProcessOutcome(
        exitCode: 128,
        stdout: '',
        stderr: "fatal: ambiguous argument '$range': unknown revision",
      );
    }
    final String output = commits
        .map((commit) => '${commit.hash}\u001f${commit.message}\n')
        .join('\u0000');
    return ProcessOutcome(exitCode: 0, stdout: output, stderr: '');
  }
}
