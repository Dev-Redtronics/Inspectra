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

import 'package:inspectra/src/host/host_platform.dart';
import 'package:inspectra/src/io/clock.dart';
import 'package:inspectra/src/io/environment.dart';
import 'package:inspectra/src/io/process_runner.dart';
import 'package:inspectra/src/io/system_process_runner.dart';

/// Everything a command needs from the outside world.
///
/// The production context wraps the real process environment; tests create
/// a context with in-memory sinks, a fixed clock and fake processes, and run
/// the complete command line in-process.
final class CommandContext {
  /// Creates a context.
  ///
  /// [out] and [err] receive standard output and standard error;
  /// [outIsTerminal] and [supportsAnsi] drive colour detection; [sleep] is
  /// used between network retries.
  CommandContext({
    required this.environment,
    required this.clock,
    required this.processRunner,
    required this.host,
    required this.workingDirectory,
    required this.out,
    required this.err,
    this.outIsTerminal = false,
    this.supportsAnsi = false,
    this.sleep = Future.delayed,
  });

  /// Creates the context of the running process.
  ///
  /// Returns the production context.
  factory CommandContext.system() => CommandContext(
    environment: Environment.current(),
    clock: const Clock.system(),
    processRunner: const SystemProcessRunner(),
    host: HostPlatform.current(),
    workingDirectory: Directory.current.path,
    out: stdout,
    err: stderr,
    outIsTerminal: stdout.hasTerminal,
    supportsAnsi: stdout.supportsAnsiEscapes,
  );

  /// The environment variables.
  final Environment environment;

  /// The clock.
  final Clock clock;

  /// Starts external processes.
  final ProcessRunner processRunner;

  /// The host platform.
  final HostPlatform host;

  /// The directory relative paths are resolved against.
  final String workingDirectory;

  /// Standard output.
  final StringSink out;

  /// Standard error.
  final StringSink err;

  /// Whether standard output is a terminal.
  final bool outIsTerminal;

  /// Whether the terminal understands ANSI escape sequences.
  final bool supportsAnsi;

  /// Waits between network retries.
  final Future<void> Function(Duration delay) sleep;
}
