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

import 'dart:io';

import 'package:path/path.dart' as p;

import '../host/host_platform.dart';
import '../io/process_runner.dart';
import '../model/inspectra_exception.dart';
import 'pre_commit_script.dart';

/// Installs and removes the Inspectra pre-commit hook.
///
/// The hook location is asked from Git (`git rev-parse --git-path
/// hooks/pre-commit`), which honours `core.hooksPath`, linked worktrees and
/// `$GIT_DIR`. A hook that was not installed by Inspectra is never modified.
final class GitHookManager {
  /// Creates a manager for the repository containing [workingDirectory].
  const GitHookManager({
    required this.processRunner,
    required this.workingDirectory,
    required this.host,
  });

  /// Runs `git`.
  final ProcessRunner processRunner;

  /// A directory inside the Git repository.
  final String workingDirectory;

  /// The host platform; hooks are made executable on POSIX hosts.
  final HostPlatform host;

  /// Resolves the absolute path of the pre-commit hook.
  ///
  /// Returns the path.
  ///
  /// Throws an [UnavailableException] when Git is not installed and an
  /// [InvalidUsageException] outside of a Git repository.
  Future<String> hookPath() async {
    final (int, String) outcome;
    try {
      final result = await processRunner.run('git', const <String>[
        'rev-parse',
        '--git-path',
        'hooks/pre-commit',
      ], workingDirectory: workingDirectory);
      outcome = (result.exitCode, result.stdout.trim());
    } on ProcessException {
      throw const UnavailableException(
        'Git is not installed or not on the PATH.',
      );
    }
    final (exitCode, path) = outcome;
    if (exitCode != 0 || path.isEmpty) {
      throw const InvalidUsageException(
        'No Git repository found. Run this command inside a Git repository.',
      );
    }
    return p.normalize(p.join(workingDirectory, path));
  }

  /// Installs the hook.
  ///
  /// Returns the hook path and whether the hook was already installed.
  ///
  /// Throws an [InvalidUsageException] when a foreign hook exists.
  Future<(String, bool)> install() async {
    final path = await hookPath();
    final file = File(path);
    if (file.existsSync()) {
      final existing = file.readAsStringSync();
      if (existing.contains(PreCommitScript.marker)) {
        file.writeAsStringSync(PreCommitScript.content);
        return (path, true);
      }
      throw InvalidUsageException(
        'A pre-commit hook already exists at $path. It was not modified; '
        'call "inspectra audit" and "inspectra typosquat" from it or remove '
        'it first.',
      );
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(PreCommitScript.content);
    await _makeExecutable(path);
    return (path, false);
  }

  /// Removes the hook if Inspectra installed it.
  ///
  /// Returns the removed path, or `null` when there was nothing to remove.
  Future<String?> remove() async {
    final path = await hookPath();
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    if (!file.readAsStringSync().contains(PreCommitScript.marker)) {
      return null;
    }
    file.deleteSync();
    return path;
  }

  /// Marks [path] executable on POSIX hosts.
  ///
  /// Throws an [UnavailableException] when `chmod` fails.
  Future<void> _makeExecutable(String path) async {
    if (host.isWindows) {
      return;
    }
    final result = await processRunner.run('chmod', <String>['755', path]);
    if (!result.succeeded) {
      throw UnavailableException(
        'Could not make $path executable: '
        '${result.stderr.trim()}',
      );
    }
  }
}
