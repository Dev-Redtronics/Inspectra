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
import 'package:inspectra/src/builders/quality_builder.dart';
import 'package:test/test.dart';

/// Tests the format, lint and style builders.
void main() {
  final builders = <String, Builder>{
    'format': formatBuilder(BuilderOptions.empty),
    'lint': lintBuilder(BuilderOptions.empty),
    'style': styleBuilder(BuilderOptions.empty),
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

  group('style on build', () {
    const builder = QualityBuilder.style(inPackage: _everyAsset);
    const pubspec =
        'name: a\ninspectra:\n  style:\n    enabled: true\n'
        '    run_on_build: true\n    preset: strict\n'
        '    license_header: tool/header.txt\n';

    test('checks the build sources and writes the report', () async {
      final TestBuilderResult result = await testBuilder(
        builder,
        {
          'a|pubspec.yaml': pubspec,
          'a|tool/header.txt': '// Header\n',
          'a|lib/a.dart': '// Header\n\n/// A.\nclass A {}\n',
          'a|lib/b.dart': 'class Other {}\n',
        },
        rootPackage: 'a',
        outputs: {
          'a|inspectra/style.json': decodedMatches(
            allOf(
              contains('"failed": true'),
              contains('file_named_after_type'),
            ),
          ),
        },
      );

      expect(result.succeeded, isFalse);
    });

    test('reads a header template that is no build source from disk', () async {
      final logs = <String>[];
      final TestBuilderResult result = await testBuilder(
        builder,
        {
          'a|pubspec.yaml': pubspec.replaceAll(
            'tool/header.txt',
            'tool/license_header.txt',
          ),
          'a|lib/a.dart': '/// A.\nclass A {}\n',
        },
        rootPackage: 'a',
        onLog: (record) => logs.add(record.message),
        outputs: {'a|inspectra/style.json': anything},
      );

      expect(result.succeeded, isFalse);
      expect(logs.join('\n'), contains('is not a build_runner source'));
      expect(logs.join('\n'), contains('[license_header]'));
    });

    test('fails without its header template', () async {
      final TestBuilderResult result = await testBuilder(
        builder,
        {'a|pubspec.yaml': pubspec, 'a|lib/a.dart': 'class A {}'},
        rootPackage: 'a',
        outputs: {},
      );

      expect(result.succeeded, isFalse);
    });
  });
}

/// Treats every asset as a file of the package.
bool _everyAsset(AssetId id) => true;
