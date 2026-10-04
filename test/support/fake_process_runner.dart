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

import 'package:inspectra/inspectra.dart';

/// A [ProcessRunner] that answers from a script instead of starting
/// processes.
final class FakeProcessRunner implements ProcessRunner {
  /// Creates a runner answering every call with [handler].
  FakeProcessRunner(this.handler);

  /// Produces the outcome of a call to `executable` with `arguments`.
  final ProcessOutcome Function(String executable, List<String> arguments)
  handler;

  /// Every call as `executable arguments...`, in order.
  final calls = <String>[];

  /// Records the call and answers it from [handler].
  ///
  /// Returns the scripted outcome.
  @override
  Future<ProcessOutcome> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
    Duration? timeout,
  }) async {
    calls.add(<String>[executable, ...arguments].join(' '));
    return handler(executable, arguments);
  }
}
