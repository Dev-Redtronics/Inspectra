import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inspectra/builder.dart';
import 'package:inspectra/inspectra.dart';
import 'package:test/test.dart';

const _pubspecEnabled = '''
name: a
inspectra:
  api:
    enabled: true
''';

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
