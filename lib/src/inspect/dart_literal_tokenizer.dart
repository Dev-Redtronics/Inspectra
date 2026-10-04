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

import 'package:inspectra/src/inspect/string_literal.dart';

/// Extracts the string literals of a Dart source file.
///
/// A real tokenizer is needed to measure string entropy reliably: a line
/// based regular expression misreads escaped quotes, mixes up `'` and `"`,
/// cannot see triple quoted strings and treats comments as code. This
/// tokenizer understands line and nested block comments, raw strings, triple
/// quotes, escapes and `$identifier` and `${expression}` interpolation.
/// Interpolations split a literal into separate values.
final class DartLiteralTokenizer {
  /// Creates a tokenizer for the Dart source text `_source`.
  DartLiteralTokenizer(this._source);

  /// The source text.
  final String _source;

  /// The current position.
  var _index = 0;

  /// The current one-based line.
  var _line = 1;

  /// The extracted literals.
  final _literals = <StringLiteral>[];

  /// Extracts every string literal.
  ///
  /// Returns the literals in source order.
  List<StringLiteral> extract() {
    while (_index < _source.length) {
      _step();
    }
    return _literals;
  }

  /// Consumes the token at the current position.
  void _step() {
    final String char = _source[_index];
    if (char == '\n') {
      _line++;
      _index++;
      return;
    }
    if (_source.startsWith('//', _index)) {
      final int end = _source.indexOf('\n', _index);
      _index = end < 0 ? _source.length : end;
      return;
    }
    if (_source.startsWith('/*', _index)) {
      _skipBlockComment();
      return;
    }
    if (char == "'" || char == '"') {
      _readString(raw: false);
      return;
    }
    if (_isRawStringStart()) {
      _index++;
      _readString(raw: true);
      return;
    }
    _index++;
  }

  /// Whether a raw string prefix `r` starts at the current position.
  ///
  /// Returns `true` when `r` is followed by a quote and not part of an
  /// identifier.
  bool _isRawStringStart() {
    final int next = _index + 1;
    if (_source[_index] != 'r' || next >= _source.length) {
      return false;
    }
    final String quote = _source[next];
    final String previous = _index == 0 ? ' ' : _source[_index - 1];
    return (quote == "'" || quote == '"') && !_isIdentifierChar(previous);
  }

  /// Skips a possibly nested block comment.
  void _skipBlockComment() {
    var depth = 0;
    while (_index < _source.length) {
      if (_source.startsWith('/*', _index)) {
        depth++;
        _index += 2;
        continue;
      }
      if (_source.startsWith('*/', _index)) {
        depth--;
        _index += 2;
        if (depth == 0) {
          return;
        }
        continue;
      }
      _advanceOne();
    }
  }

  /// Reads the string literal starting at the current quote.
  ///
  /// [raw] disables escapes and interpolation.
  void _readString({required bool raw}) {
    final String quote = _source[_index];
    final bool triple = _source.startsWith(quote * 3, _index);
    final String delimiter = triple ? quote * 3 : quote;
    _index += delimiter.length;
    final buffer = StringBuffer();
    int startLine = _line;
    while (_index < _source.length) {
      if (_source.startsWith(delimiter, _index)) {
        _index += delimiter.length;
        break;
      }
      final String char = _source[_index];
      if (char == '\n' && !triple) {
        break;
      }
      if (!raw && char == r'\') {
        final int end = _index + 2 > _source.length
            ? _source.length
            : _index + 2;
        buffer.write(_source.substring(_index, end));
        _advanceOne();
        if (_index < _source.length) {
          _advanceOne();
        }
        continue;
      }
      if (!raw && char == r'$') {
        _emit(buffer, startLine);
        _skipInterpolation();
        startLine = _line;
        continue;
      }
      buffer.write(char);
      _advanceOne();
    }
    _emit(buffer, startLine);
  }

  /// Skips `$identifier` or a brace balanced `${expression}`; string
  /// literals nested in the expression are extracted on their own, so their
  /// braces do not disturb the balance.
  void _skipInterpolation() {
    _index++;
    if (_index < _source.length && _source[_index] == '{') {
      var depth = 0;
      while (_index < _source.length) {
        final String char = _source[_index];
        if (char == "'" || char == '"') {
          _readString(raw: false);
          continue;
        }
        if (_isRawStringStart()) {
          _index++;
          _readString(raw: true);
          continue;
        }
        _advanceOne();
        if (char == '{') {
          depth++;
        }
        if (char == '}') {
          depth--;
        }
        if (depth == 0) {
          return;
        }
      }
      return;
    }
    while (_index < _source.length && _isIdentifierChar(_source[_index])) {
      _index++;
    }
  }

  /// Moves one character forward, counting line breaks.
  void _advanceOne() {
    if (_source[_index] == '\n') {
      _line++;
    }
    _index++;
  }

  /// Adds the buffered literal text, if any, and clears the [buffer].
  void _emit(StringBuffer buffer, int line) {
    if (buffer.isEmpty) {
      return;
    }
    _literals.add(StringLiteral(buffer.toString(), line));
    buffer.clear();
  }

  /// Whether [char] can be part of a Dart identifier.
  ///
  /// Returns `true` for letters, digits, `_` and `$`.
  static bool _isIdentifierChar(String char) =>
      RegExp(r'[A-Za-z0-9_$]').hasMatch(char);
}
