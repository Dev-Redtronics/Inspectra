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

import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/io/verbosity.dart';

/// The single channel through which Inspectra talks to its user.
///
/// Reports are written to [out] (standard output), while progress, warnings
/// and errors go to [err] (standard error). Keeping the two apart guarantees
/// that `inspectra audit --format json > report.json` produces a valid JSON
/// document even while progress messages are shown.
final class Console {
  /// Creates a console writing reports to [out] and diagnostics to [err].
  Console({
    required this.out,
    required this.err,
    required this.styler,
    this.verbosity = Verbosity.normal,
  });

  /// The sink receiving reports.
  final StringSink out;

  /// The sink receiving diagnostics.
  final StringSink err;

  /// The colour styler matching the terminal capabilities.
  final AnsiStyler styler;

  /// The configured diagnostic verbosity.
  final Verbosity verbosity;

  /// Writes a rendered report to standard output.
  ///
  /// [text] is written as is; the caller is responsible for line breaks.
  void report(String text) => out.write(text);

  /// Writes a progress [message] unless the verbosity is [Verbosity.quiet].
  void info(String message) {
    if (verbosity == Verbosity.quiet) {
      return;
    }
    err.writeln(message);
  }

  /// Writes a diagnostic [message] only in [Verbosity.verbose] mode.
  void detail(String message) {
    if (verbosity != Verbosity.verbose) {
      return;
    }
    err.writeln(styler.dim(message));
  }

  /// Writes a warning [message]; warnings are shown in every verbosity.
  void warning(String message) {
    err.writeln('${styler.yellow('warning:')} $message');
  }

  /// Writes an error [message]; errors are shown in every verbosity.
  void error(String message) {
    err.writeln('${styler.red('error:')} $message');
  }
}
