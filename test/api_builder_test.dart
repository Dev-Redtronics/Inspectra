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

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inspectra/builder.dart';
import 'package:inspectra/inspectra.dart';
import 'package:test/test.dart';

/// A pubspec of the package `a` that enables the API check.
const _pubspecEnabled = '''
name: a
inspectra:
  api:
    enabled: true
''';

/// Tests the API builder against in-memory packages.
void main() {
  final Builder builder = apiBuilder(
    const BuilderOptions({'output': 'api/a.api'}),
  );

  test('writes the dump of the public libraries', () async {
    await testBuilder(
      builder,
      {
        'a|pubspec.yaml': _pubspecEnabled,
        'a|lib/a.dart': "export 'src/b.dart';\nint answer() => 42;",
        'a|lib/extra.dart': 'class Extra {}',
        'a|lib/part.dart': "part of 'extra.dart';",
        'a|lib/src/b.dart': 'class B {}',
      },
      rootPackage: 'a',
      outputs: {
        'a|api/a.api': decodedMatches(
          '$apiDumpHeader\n'
          'library package:a/a.dart\n\n'
          'class B {}\n\n'
          'int answer();\n\n'
          'library package:a/extra.dart\n\n'
          'class Extra {}\n',
        ),
      },
    );
  });

  test('leaves out ignored libraries', () async {
    await testBuilder(
      builder,
      {
        'a|pubspec.yaml':
            '$_pubspecEnabled    ignored_libraries: [lib/testing.dart]\n',
        'a|lib/a.dart': 'class A {}',
        'a|lib/testing.dart': 'class Fake {}',
      },
      rootPackage: 'a',
      outputs: {'a|api/a.api': decodedMatches(isNot(contains('Fake')))},
    );
  });

  test('writes nothing while API validation is disabled', () async {
    await testBuilder(
      builder,
      {'a|pubspec.yaml': 'name: a\n', 'a|lib/a.dart': 'class A {}'},
      rootPackage: 'a',
      outputs: {},
    );
  });

  test('fails on a broken configuration', () async {
    final TestBuilderResult result = await testBuilder(
      builder,
      {
        'a|pubspec.yaml': 'name: a\ninspectra:\n  api:\n    enable: true\n',
        'a|lib/a.dart': 'class A {}',
      },
      rootPackage: 'a',
      outputs: {},
    );

    expect(result.succeeded, isFalse);
  });
}
