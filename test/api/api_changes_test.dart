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
import 'package:inspectra/src/api/api_parameters.dart';
import 'package:test/test.dart';

/// Tests deciding which API changes break consumers.
void main() {
  /// Compares the declarations [before] and [after] of one library.
  ///
  /// Returns every change as `kind subject`.
  List<String> classify(String before, String after) => <String>[
    for (final ApiChange change in classifyApiChanges(
      ApiSurface.parse('library package:a/a.dart\n\n$before'),
      ApiSurface.parse('library package:a/a.dart\n\n$after'),
    ))
      '${change.kind.id} ${change.subject}',
  ];

  /// Compares [before] and [after] and returns the single change.
  ApiChange only(String before, String after) => classifyApiChanges(
    ApiSurface.parse('library package:a/a.dart\n\n$before'),
    ApiSurface.parse('library package:a/a.dart\n\n$after'),
  ).single;

  test('finds no change in the same API', () {
    const api = 'class A {\n  void run();\n}\n';
    expect(classify(api, api), isEmpty);
  });

  test('removing a library, declaration or member breaks', () {
    final List<ApiChange> libraries = classifyApiChanges(
      ApiSurface.parse('library package:a/a.dart\n\nint x();\n'),
      ApiSurface.parse('library package:a/b.dart\n\nint x();\n'),
    );
    expect(
      libraries.map((change) => '${change.kind.id} ${change.subject}'),
      <String>['breaking package:a/a.dart', 'additive package:a/b.dart'],
    );
    expect(classify('int x();\nint y();\n', 'int x();\n'), <String>[
      'breaking y',
    ]);
    expect(
      classify(
        'class A {\n  void a();\n  void b();\n}\n',
        'class A {\n  void a();\n}\n',
      ),
      <String>['breaking A.b'],
    );
  });

  test('adding a declaration or member is additive', () {
    expect(classify('int x();\n', 'int x();\nint y();\n'), <String>[
      'additive y',
    ]);
    expect(
      classify(
        'class A {\n  void a();\n}\n',
        'class A {\n  void a();\n  void b();\n}\n',
      ),
      <String>['additive A.b'],
    );
    expect(
      classify('final class A {}\n', 'final class A {\n  int get b;\n}\n'),
      <String>['additive A.get b'],
    );
  });

  test('a new enum value breaks, a removed one too', () {
    expect(
      classify('enum C {\n  a, b;\n}\n', 'enum C {\n  a, c;\n}\n'),
      <String>['breaking C.b', 'breaking C.c'],
    );
    expect(
      only('enum C {\n  a;\n}\n', 'enum C {\n  a, b;\n}\n').reason,
      contains('switch statements'),
    );
  });

  test('a new abstract member breaks the implementers', () {
    expect(
      classify(
        'abstract class A {\n  void a();\n}\n',
        'abstract class A {\n  void a();\n  abstract int get b;\n}\n',
      ),
      <String>['breaking A.get b'],
    );
    expect(
      classify(
        'abstract interface class A {}\n',
        'abstract interface class A {\n  void b();\n}\n',
      ),
      <String>['breaking A.b'],
    );
    expect(
      classify(
        'sealed class A {}\n',
        'sealed class A {\n  abstract int get b;\n}\n',
      ),
      <String>['additive A.get b'],
    );
    expect(
      classify(
        'abstract interface class A {}\n',
        'abstract interface class A {\n  const A.named();\n'
            '  static int count();\n}\n',
      ),
      <String>['additive A.A.named', 'additive A.count'],
    );
  });

  test('a changed type declaration breaks', () {
    final ApiChange change = only('class A {}\n', 'final class A {}\n');
    expect(change.kind, ApiChangeKind.breaking);
    expect(change.reason, contains('type declaration changed'));
    expect(change.before, 'class A');
    expect(change.after, 'final class A');
    expect(
      only('class A {}\n', 'int A();\n').reason,
      contains('between a type and a member'),
    );
  });

  test('deprecating is additive', () {
    expect(
      only('int x();\n', '@Deprecated int x();\n').reason,
      'It was deprecated.',
    );
    final ApiChange undeprecated = only(
      'class A {\n  @Deprecated void a();\n}\n',
      'class A {\n  void a();\n}\n',
    );
    expect(undeprecated.kind, ApiChangeKind.additive);
    expect(undeprecated.reason, 'It is no longer deprecated.');
  });

  group('parameters', () {
    test('optional ones may be added where nobody overrides', () {
      expect(
        classify('int f(int a);\n', 'int f(int a, [int b = 1]);\n'),
        <String>['additive f'],
      );
      expect(
        classify(
          'class A {\n  A({required int a});\n  static void s();\n}\n',
          'class A {\n  A({required int a, int b = 0});\n'
              '  static void s({bool c = false});\n}\n',
        ),
        <String>['additive A.A', 'additive A.s'],
      );
      expect(
        classify(
          'final class A {\n  void run();\n}\n',
          'final class A {\n  void run({bool fast = false});\n}\n',
        ),
        <String>['additive A.run'],
      );
      expect(
        only(
          'extension E on int {\n  int twice();\n}\n',
          'extension E on int {\n  int twice([int times = 2]);\n}\n',
        ).reason,
        'Only optional parameters were added.',
      );
    });

    test('optional ones break members that can be overridden', () {
      final ApiChange change = only(
        'class A {\n  void run();\n}\n',
        'class A {\n  void run({bool fast = false});\n}\n',
      );
      expect(change.kind, ApiChangeKind.breaking);
      expect(change.reason, contains('override'));
    });

    test('required, removed, reordered or retyped ones break', () {
      expect(classify('int f(int a);\n', 'int f(int a, int b);\n'), <String>[
        'breaking f',
      ]);
      expect(
        classify(
          'int f({int a = 0});\n',
          'int f({int a = 0, required int b});\n',
        ),
        <String>['breaking f'],
      );
      expect(
        classify(
          'int f([int a = 0, int b = 1]);\n',
          'int f([int b = 1, int a = 0]);\n',
        ),
        <String>['breaking f'],
      );
      expect(classify('int f({int a = 0});\n', 'int f();\n'), <String>[
        'breaking f',
      ]);
      expect(classify('int f(int a);\n', 'int f(num a);\n'), <String>[
        'breaking f',
      ]);
      expect(classify('int f(int a);\n', 'num f(int a);\n'), <String>[
        'breaking f',
      ]);
      expect(
        classify('int f([int a = 0]);\n', 'int f([int a = 0], {int b = 1});\n'),
        <String>['breaking f'],
      );
      expect(
        classify('int f({int a = 0});\n', 'int f({int a = 1});\n'),
        <String>['breaking f'],
      );
    });

    test('parses only executables', () {
      expect(ApiParameters.of('final int x;'), isNull);
      expect(ApiParameters.of('const int x = f(1);'), isNull);
      final ApiParameters parameters = ApiParameters.of(
        'Map<K, V> f<K, V>(K key, void Function(K, V) each, [V? fallback]);',
      )!;
      expect(parameters.prefix, 'Map<K, V> f<K, V>');
      expect(parameters.requiredPositional, <String>[
        'K key',
        'void Function(K, V) each',
      ]);
      expect(parameters.optionalPositional, <String>['V? fallback']);
      expect(parameters.named, isEmpty);
    });
  });

  test('a changed constant value breaks', () {
    final ApiChange change = only(
      'const int sides = 4;\n',
      'const int sides = 5;\n',
    );
    expect(change.kind, ApiChangeKind.breaking);
    expect(change.reason, startsWith('The value changed'));
    expect(
      only('const int sides = 4;\n', 'const num sides = 4;\n').reason,
      'The signature changed.',
    );
  });

  test('serializes a change', () {
    expect(only('int x();\n', 'int x(int a);\n').toJson(), <String, Object?>{
      'kind': 'breaking',
      'library': 'package:a/a.dart',
      'declaration': 'x',
      'reason': 'The signature changed.',
      'before': 'int x();',
      'after': 'int x(int a);',
    });
  });
}
