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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'process_outcome.dart';
import 'process_runner.dart';

/// The production [ProcessRunner] backed by `dart:io`.
final class SystemProcessRunner implements ProcessRunner {
  /// Creates a runner that starts real operating system processes.
  const SystemProcessRunner();

  /// The exit code reported for a process that was killed on timeout.
  static const int timedOutExitCode = -1;

  /// Starts [executable], collects its output and enforces [timeout].
  ///
  /// Output is decoded leniently so that a tool printing invalid UTF-8 can
  /// never crash Inspectra.
  ///
  /// Returns the outcome of the process.
  @override
  Future<ProcessOutcome> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
    Duration? timeout,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
    );
    const decoder = Utf8Decoder(allowMalformed: true);
    final stdoutText = process.stdout.transform(decoder).join();
    final stderrText = process.stderr.transform(decoder).join();
    final exitCode = await _awaitExit(process, timeout);
    final collectedStdout = await stdoutText;
    final collectedStderr = await stderrText;
    if (exitCode == null) {
      return ProcessOutcome(
        exitCode: timedOutExitCode,
        stdout: collectedStdout,
        stderr: '$executable did not finish within $timeout and was killed.',
      );
    }
    return ProcessOutcome(
      exitCode: exitCode,
      stdout: collectedStdout,
      stderr: collectedStderr,
    );
  }

  /// Waits for [process] to exit, killing it when [timeout] elapses first.
  ///
  /// Returns the exit code, or `null` when the process was killed.
  Future<int?> _awaitExit(Process process, Duration? timeout) async {
    if (timeout == null) {
      return process.exitCode;
    }
    try {
      return await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill();
      await process.exitCode;
      return null;
    }
  }
}
