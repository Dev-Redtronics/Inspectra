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

import 'package:inspectra/src/inspect/dart_literal_tokenizer.dart';
import 'package:inspectra/src/inspect/string_literal.dart';
import 'package:test/test.dart';

/// Tests string literal extraction from Dart source.
void main() {
  /// Extracts the literal values of [source].
  List<String> values(String source) =>
      DartLiteralTokenizer(source).extract().map((l) => l.value).toList();

  test('extracts single, double, raw and triple quoted strings', () {
    expect(
      values("a('x'); b(\"y\"); c(r'\\d'); d('''multi\nline''');"),
      <String>['x', 'y', r'\d', 'multi\nline'],
    );
  });

  test('skips comments and handles escapes and other quotes', () {
    const source = "// 'no'\n/* 'no' /* nested */ */ f('it\\'s \"ok\"');";
    expect(values(source), <String>['it\\\'s "ok"']);
  });

  test('splits literals at interpolations', () {
    expect(values(r"f('a${b + '}'}c$d e');"), <String>['a', '}', 'c', ' e']);
  });

  test('reports the starting line', () {
    final List<StringLiteral> literals = DartLiteralTokenizer("\n\nf('x');")
        .extract();
    expect(literals.single.line, 3);
  });

  test('does not treat identifiers ending in r as raw prefixes', () {
    expect(values("var r = 1; ber('x');"), <String>['x']);
  });
}
