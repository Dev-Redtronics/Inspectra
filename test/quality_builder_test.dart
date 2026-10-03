import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inspectra/builder.dart';
import 'package:test/test.dart';

void main() {
  final builders = <String, Builder>{
    'format': formatBuilder(BuilderOptions.empty),
    'lint': lintBuilder(BuilderOptions.empty),
  };

  for (final MapEntry(key: name, value: builder) in builders.entries) {
    group(name, () {
      test('does nothing while the check is disabled', () async {
        await testBuilder(
          builder,
          {'a|pubspec.yaml': 'name: a\n', 'a|lib/a.dart': 'class  A{}'},
          rootPackage: 'a',
          outputs: {},
        );
      });

      test('does nothing unless run_on_build is set', () async {
        await testBuilder(
          builder,
          {
            'a|pubspec.yaml':
                'name: a\ninspectra:\n  $name:\n    enabled: true\n',
            'a|lib/a.dart': 'class  A{}',
          },
          rootPackage: 'a',
          outputs: {},
        );
      });

      test('fails on a broken configuration', () async {
        final TestBuilderResult result = await testBuilder(
          builder,
          {
            'a|pubspec.yaml':
                'name: a\ninspectra:\n  $name:\n    enable: true\n',
            'a|lib/a.dart': 'class A {}',
          },
          rootPackage: 'a',
          outputs: {},
        );

        expect(result.succeeded, isFalse);
      });
    });
  }
}
