/*
 * Copyright 2026 Redtronics
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
import 'package:test/test.dart';

/// Tests the format and lint builders.
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
