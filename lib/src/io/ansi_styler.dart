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

import 'package:inspectra/src/io/environment.dart';
import 'package:inspectra/src/model/severity.dart';

/// Applies ANSI colours and text attributes to strings when enabled.
///
/// A single instance is created per run. When colours are disabled every
/// method returns its input unchanged, which keeps all report writers free of
/// colour conditionals.
final class AnsiStyler {
  /// Creates a styler that emits escape sequences only when [enabled].
  const AnsiStyler({required this.enabled});

  /// Whether escape sequences are emitted.
  final bool enabled;

  /// The escape sequence that resets all attributes.
  static const _reset = '\x1B[0m';

  /// Decides whether colours should be used.
  ///
  /// The decision honours, in this order: the `--no-color` flag
  /// ([noColorFlag]), the `NO_COLOR` convention (https://no-color.org), the
  /// `FORCE_COLOR` convention, `TERM=dumb`, and finally whether the output is
  /// an ANSI capable terminal ([hasTerminal] and [supportsAnsi]).
  ///
  /// Returns `true` when colours should be emitted.
  static bool detect({
    required Environment environment,
    required bool noColorFlag,
    required bool hasTerminal,
    required bool supportsAnsi,
  }) {
    if (noColorFlag || environment['NO_COLOR'] != null) {
      return false;
    }
    final String? forced = environment['FORCE_COLOR'];
    if (forced != null && forced != '0') {
      return true;
    }
    if (environment['TERM'] == 'dumb') {
      return false;
    }
    return hasTerminal && supportsAnsi;
  }

  /// Wraps [text] in the escape sequence [code] when colours are enabled.
  ///
  /// Returns the possibly decorated text.
  String _wrap(String code, String text) {
    if (!enabled) {
      return text;
    }
    return '\x1B[${code}m$text$_reset';
  }

  /// Returns [text] in red.
  String red(String text) => _wrap('31', text);

  /// Returns [text] in green.
  String green(String text) => _wrap('32', text);

  /// Returns [text] in yellow.
  String yellow(String text) => _wrap('33', text);

  /// Returns [text] in cyan.
  String cyan(String text) => _wrap('36', text);

  /// Returns [text] in bold.
  String bold(String text) => _wrap('1', text);

  /// Returns [text] dimmed.
  String dim(String text) => _wrap('2', text);

  /// Returns the bracketed, padded and coloured label of [severity], for
  /// example `[HIGH]    ` in red.
  ///
  /// The padding aligns the text that follows the label across lines.
  String severityLabel(Severity severity) {
    final String label = '[${severity.label}]'.padRight(11);
    return switch (severity) {
      Severity.critical => red(bold(label)),
      Severity.high => red(label),
      Severity.medium => yellow(label),
      Severity.low => cyan(label),
      Severity.unknown => dim(label),
    };
  }
}
