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

import 'package:inspectra/src/api/api_declaration.dart';

/// The public API of a package as recorded in its API dump: every public
/// library with its declarations by name.
///
/// The dump is the format `api dump` writes; parsing it does not need the
/// sources, so the dump committed at an earlier release can be compared
/// with the current one.
final class ApiSurface {
  /// Creates the surface of [libraries], keyed by their URI.
  const ApiSurface(this.libraries);

  /// Parses the API [dump].
  ///
  /// Returns the surface; lines it does not understand are kept as single
  /// declarations, so nothing is lost.
  factory ApiSurface.parse(String dump) {
    final libraries = <String, Map<String, ApiDeclaration>>{};
    final List<String> lines = dump
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    Map<String, ApiDeclaration>? current;
    var index = 0;
    while (index < lines.length) {
      final String line = lines[index];
      index++;
      if (line.trim().isEmpty || line.startsWith('//')) {
        continue;
      }
      if (line.startsWith('library ')) {
        current = libraries.putIfAbsent(
          line.substring('library '.length).trim(),
          () => <String, ApiDeclaration>{},
        );
        continue;
      }
      final Map<String, ApiDeclaration> declarations = current ??= libraries
          .putIfAbsent('', () => <String, ApiDeclaration>{});
      if (line.endsWith(' {}')) {
        final String header = line.substring(0, line.length - 3);
        declarations[typeName(header)] = ApiDeclaration(
          name: typeName(header),
          line: header,
          isType: true,
        );
        continue;
      }
      if (!line.endsWith(' {')) {
        declarations[keyOf(line)] = ApiDeclaration(
          name: keyOf(line),
          line: line.trim(),
        );
        continue;
      }
      final String header = line.substring(0, line.length - 2);
      final body = <String>[];
      while (index < lines.length && lines[index] != '}') {
        body.add(lines[index].trim());
        index++;
      }
      index++;
      final bool isEnum = _isEnum(header);
      final String? first = body.firstOrNull;
      final bool hasValues = isEnum && first != null && _values.hasMatch(first);
      declarations[typeName(header)] = ApiDeclaration(
        name: typeName(header),
        line: header,
        isType: true,
        values: hasValues
            ? first.substring(0, first.length - 1).split(', ')
            : const <String>[],
        members: <String, String>{
          for (final String member in hasValues ? body.skip(1) : body)
            if (member.isNotEmpty) keyOf(member): member,
        },
      );
    }
    return ApiSurface(libraries);
  }

  /// The line of enum values: identifiers separated by commas.
  static final _values = RegExp(r'^[A-Za-z_$][\w$]*(, [A-Za-z_$][\w$]*)*;$');

  /// The keywords that start the name of a type in its header.
  static const _typeKeywords = <String>{'class', 'enum', 'extension', 'mixin'};

  /// The declarations of every public library, keyed by library URI and
  /// then by declaration name.
  final Map<String, Map<String, ApiDeclaration>> libraries;

  /// Returns [line] without the `@Deprecated ` prefix of the dump.
  static String withoutDeprecation(String line) {
    final String trimmed = line.trim();
    return trimmed.startsWith('@Deprecated ')
        ? trimmed.substring('@Deprecated '.length)
        : trimmed;
  }

  /// Returns whether [line] is marked `@Deprecated`.
  static bool isDeprecated(String line) =>
      line.trim().startsWith('@Deprecated ');

  /// Returns the name of the type declared by [header], such as `Shape`
  /// for `abstract base class Shape<T> implements Comparable<Shape>`; an
  /// unnamed extension is named by its whole header.
  static String typeName(String header) {
    final String text = withoutDeprecation(header);
    final List<String> words = text.split(' ');
    int keyword = words.indexWhere(_typeKeywords.contains);
    if (keyword < 0) {
      return text;
    }
    final bool twoWords =
        keyword + 1 < words.length &&
        (words[keyword] == 'mixin' && words[keyword + 1] == 'class' ||
            words[keyword] == 'extension' && words[keyword + 1] == 'type');
    keyword += twoWords ? 1 : 0;
    final bool unnamed =
        keyword + 1 >= words.length || words[keyword + 1] == 'on';
    if (unnamed) {
      return text;
    }
    return words[keyword + 1].split(RegExp('[<(]')).first;
  }

  /// Returns the name that identifies the declaration or member [line]:
  /// the name of a function, constructor, variable or typedef, `get x` and
  /// `set x` for accessors, and `operator ==` for operators.
  static String keyOf(String line) {
    String text = withoutDeprecation(line);
    if (text.endsWith(';')) {
      text = text.substring(0, text.length - 1).trimRight();
    }
    final int assignment = topLevelIndexOf(text, ' = ');
    final String before = assignment >= 0
        ? text.substring(0, assignment)
        : text.endsWith(')')
        ? text.substring(0, openingOf(text, text.length - 1))
        : text;
    final List<String> words = before
        .replaceAll(RegExp('<[^<>]*>'), '')
        .trim()
        .split(' ');
    final String name = words.last;
    final String previous = words.length > 1 ? words[words.length - 2] : '';
    final bool qualified =
        previous == 'get' || previous == 'set' || previous == 'operator';
    return qualified ? '$previous $name' : name;
  }

  /// Returns the index of [pattern] in [text] outside of brackets, quotes
  /// and parentheses, or `-1` when it occurs only inside them.
  static int topLevelIndexOf(String text, String pattern) {
    var depth = 0;
    String? quote;
    for (var index = 0; index < text.length; index++) {
      final String char = text[index];
      if (quote != null) {
        quote = char == quote ? null : quote;
        continue;
      }
      if (char == "'" || char == '"') {
        quote = char;
        continue;
      }
      if (depth == 0 && text.startsWith(pattern, index)) {
        return index;
      }
      if ('([{<'.contains(char)) {
        depth++;
      }
      if (')]}>'.contains(char)) {
        depth--;
      }
    }
    return -1;
  }

  /// Returns the index of the parenthesis that the closing parenthesis at
  /// [closing] of [text] matches, or `0` when there is none.
  static int openingOf(String text, int closing) {
    var depth = 0;
    for (var index = closing; index >= 0; index--) {
      final String char = text[index];
      if (char == ')') {
        depth++;
      }
      if (char == '(') {
        depth--;
        if (depth == 0) {
          return index;
        }
      }
    }
    return 0;
  }

  /// Returns whether [header] declares an enum.
  static bool _isEnum(String header) =>
      withoutDeprecation(header).split(' ').contains('enum');
}
