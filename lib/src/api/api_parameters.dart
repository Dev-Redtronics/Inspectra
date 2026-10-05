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

import 'package:inspectra/src/api/api_surface.dart';

/// The parameter list of a function, method or constructor line of an API
/// dump, split into the parts that decide whether callers still compile.
final class ApiParameters {
  /// Creates the parameters of a signature: the text [prefix] before the
  /// list, the [requiredPositional] parameters, the [optionalPositional]
  /// ones in brackets and the [named] ones in braces.
  const ApiParameters({
    required this.prefix,
    required this.requiredPositional,
    required this.optionalPositional,
    required this.named,
  });

  /// Reads the parameters of the executable [line].
  ///
  /// Returns the parameters, or `null` when [line] has no parameter list,
  /// such as a field or a getter.
  static ApiParameters? of(String line) {
    String text = ApiSurface.withoutDeprecation(line);
    if (text.endsWith(';')) {
      text = text.substring(0, text.length - 1).trimRight();
    }
    if (!text.endsWith(')') || ApiSurface.topLevelIndexOf(text, ' = ') >= 0) {
      return null;
    }
    final int opening = ApiSurface.openingOf(text, text.length - 1);
    final String inner = text.substring(opening + 1, text.length - 1);
    final int optional = _sectionStart(inner);
    final String positional = optional < 0
        ? inner
        : inner.substring(0, optional);
    final String section = optional < 0 ? '' : inner.substring(optional);
    final bool isNamed = section.startsWith('{');
    final List<String> optionals = section.isEmpty
        ? const <String>[]
        : _split(section.substring(1, section.length - 1));
    return ApiParameters(
      prefix: text.substring(0, opening),
      requiredPositional: _split(positional),
      optionalPositional: isNamed ? const <String>[] : optionals,
      named: isNamed ? optionals : const <String>[],
    );
  }

  /// The text before the parameter list: modifiers, return type and name.
  final String prefix;

  /// The required positional parameters, as written.
  final List<String> requiredPositional;

  /// The optional positional parameters, as written.
  final List<String> optionalPositional;

  /// The named parameters, as written, including `required` ones.
  final List<String> named;

  /// Whether [newer] only adds optional parameters to these, so that every
  /// existing call still compiles.
  bool onlyAddsOptional(ApiParameters newer) {
    final bool samePositional =
        prefix == newer.prefix &&
        _equal(requiredPositional, newer.requiredPositional);
    if (!samePositional) {
      return false;
    }
    final bool keepsOptional = _isPrefix(
      optionalPositional,
      newer.optionalPositional,
    );
    final bool keepsNamed = named.every(newer.named.contains);
    final bool addsOnlyOptionalNamed = newer.named
        .where((parameter) => !named.contains(parameter))
        .every((parameter) => !parameter.startsWith('required '));
    final bool mixes =
        optionalPositional.isNotEmpty && newer.named.isNotEmpty ||
        named.isNotEmpty && newer.optionalPositional.isNotEmpty;
    return keepsOptional && keepsNamed && addsOnlyOptionalNamed && !mixes;
  }

  /// Returns where the optional section of [inner] starts, or `-1`.
  static int _sectionStart(String inner) {
    final int named = ApiSurface.topLevelIndexOf(inner, '{');
    final int positional = ApiSurface.topLevelIndexOf(inner, '[');
    return named >= 0 ? named : positional;
  }

  /// Splits [list] at its top-level commas.
  ///
  /// Returns the trimmed, non-empty parameters.
  static List<String> _split(String list) {
    final parameters = <String>[];
    var rest = list;
    while (rest.isNotEmpty) {
      final int comma = ApiSurface.topLevelIndexOf(rest, ',');
      final String parameter = comma < 0 ? rest : rest.substring(0, comma);
      if (parameter.trim().isNotEmpty) {
        parameters.add(parameter.trim());
      }
      rest = comma < 0 ? '' : rest.substring(comma + 1);
    }
    return parameters;
  }

  /// Returns whether [a] and [b] hold the same parameters in order.
  static bool _equal(List<String> a, List<String> b) =>
      a.length == b.length && _isPrefix(a, b);

  /// Returns whether [prefix] starts [list].
  static bool _isPrefix(List<String> prefix, List<String> list) {
    if (prefix.length > list.length) {
      return false;
    }
    for (var index = 0; index < prefix.length; index++) {
      if (prefix[index] != list[index]) {
        return false;
      }
    }
    return true;
  }
}
