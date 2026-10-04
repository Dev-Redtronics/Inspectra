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

import 'package:inspectra/src/io/process_outcome.dart';

/// Runs external processes such as `git`, `dart pub add` and `trivy`.
///
/// Commands depend on this interface instead of `dart:io` directly so that
/// tests can replace every external tool with a deterministic fake.
abstract interface class ProcessRunner {
  /// Runs [executable] with [arguments] and waits for it to finish.
  ///
  /// [workingDirectory] defaults to the current directory. [runInShell] must
  /// be `true` to start Windows batch shims such as `dart.bat`. When
  /// [timeout] elapses the process is killed and a [ProcessOutcome] with
  /// exit code `-1` is returned whose stderr explains the timeout.
  ///
  /// Returns the outcome of the process.
  ///
  /// Throws a `ProcessException` when [executable] cannot be started.
  Future<ProcessOutcome> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
    Duration? timeout,
  });
}
