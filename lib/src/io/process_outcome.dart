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

/// The result of running an external process to completion.
final class ProcessOutcome {
  /// Creates an outcome from the process [exitCode] and its decoded
  /// [stdout] and [stderr] output.
  const ProcessOutcome({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  /// The exit code reported by the operating system.
  final int exitCode;

  /// Everything the process wrote to standard output, decoded as UTF-8.
  final String stdout;

  /// Everything the process wrote to standard error, decoded as UTF-8.
  final String stderr;

  /// Whether the process exited with code `0`.
  bool get succeeded => exitCode == 0;
}
