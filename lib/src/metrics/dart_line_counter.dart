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

import 'package:inspectra/src/metrics/line_counts.dart';

/// The markers of open work in comments.
final _todo = RegExp(r'\b(TODO|FIXME|HACK|XXX)\b');

/// Counts the lines of the Dart [source] by what they hold.
///
/// The source is scanned, not parsed: comments inside strings, nested block
/// comments, raw and multi-line strings and interpolations are told apart,
/// so a `//` in a string is code. Lines of a multi-line string are code.
///
/// Returns the counts.
LineCounts countDartLines(String source) {
  var total = 0;
  var code = 0;
  var comment = 0;
  var documentation = 0;
  var blank = 0;
  var todos = 0;
  var hasCode = false;
  var hasComment = false;
  var isDoc = false;
  final contexts = <(String, String, bool, int)>[('code', '', false, 0)];

  void endLine() {
    total++;
    if (hasCode) {
      code++;
    }
    if (!hasCode && hasComment) {
      comment++;
      documentation += isDoc ? 1 : 0;
    }
    if (!hasCode && !hasComment) {
      blank++;
    }
    hasCode = false;
    hasComment = false;
    isDoc = false;
  }

  bool at(String text, int index) => source.startsWith(text, index);

  bool isIdentifier(int index) =>
      index >= 0 && RegExp(r'[A-Za-z0-9_$]').hasMatch(source[index]);

  var index = 0;
  while (index < source.length) {
    final String char = source[index];
    if (char == '\n') {
      endLine();
      index++;
      continue;
    }
    final bool whitespace = char == ' ' || char == '\t' || char == '\r';
    final (String kind, String delimiter, bool flag, int depth) = contexts.last;
    if (kind == 'block') {
      if (!whitespace) {
        hasComment = true;
        isDoc = isDoc || flag;
      }
      if (_todo.matchAsPrefix(source, index) != null) {
        todos++;
      }
      if (at('/*', index)) {
        contexts.last = (kind, delimiter, flag, depth + 1);
        index += 2;
        continue;
      }
      if (at('*/', index)) {
        contexts.removeLast();
        if (depth > 1) {
          contexts.add((kind, delimiter, flag, depth - 1));
        }
        index += 2;
        continue;
      }
      index++;
      continue;
    }
    if (kind == 'string') {
      hasCode = hasCode || !whitespace;
      if (!flag && char == r'\') {
        index += 2;
        continue;
      }
      if (!flag && at(r'${', index)) {
        contexts.add(('interpolation', '', false, 1));
        index += 2;
        continue;
      }
      if (at(delimiter, index)) {
        contexts.removeLast();
        index += delimiter.length;
        continue;
      }
      index++;
      continue;
    }
    if (whitespace) {
      index++;
      continue;
    }
    if (at('//', index)) {
      final int newline = source.indexOf('\n', index);
      final int end = newline < 0 ? source.length : newline;
      final String text = source.substring(index, end);
      hasComment = true;
      isDoc = isDoc || text.startsWith('///') && !text.startsWith('////');
      todos += _todo.hasMatch(text) ? 1 : 0;
      index = end;
      continue;
    }
    if (at('/*', index)) {
      hasComment = true;
      contexts.add(('block', '', at('/**', index) && !at('/**/', index), 1));
      index += 2;
      continue;
    }
    final bool raw =
        char == 'r' &&
        index + 1 < source.length &&
        (source[index + 1] == "'" || source[index + 1] == '"') &&
        !isIdentifier(index - 1);
    final int quote = raw ? index + 1 : index;
    final bool opensString =
        quote < source.length && (source[quote] == "'" || source[quote] == '"');
    hasCode = true;
    if (opensString) {
      final String single = source[quote];
      final String triple = single * 3;
      final opening = at(triple, quote) ? triple : single;
      contexts.add(('string', opening, raw, 0));
      index = quote + opening.length;
      continue;
    }
    if (kind == 'interpolation' && char == '{') {
      contexts.last = (kind, delimiter, flag, depth + 1);
    }
    if (kind == 'interpolation' && char == '}') {
      contexts.removeLast();
      if (depth > 1) {
        contexts.add((kind, delimiter, flag, depth - 1));
      }
    }
    index++;
  }
  if (source.isNotEmpty && !source.endsWith('\n')) {
    endLine();
  }
  return LineCounts(
    total: total,
    code: code,
    comment: comment,
    documentation: documentation,
    blank: blank,
    todos: todos,
  );
}
