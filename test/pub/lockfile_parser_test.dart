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

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/pub/lockfile_parser.dart';
import 'package:test/test.dart';

/// Tests `pubspec.lock` parsing and classification.
void main() {
  const content = '''
packages:
  zeta:
    dependency: transitive
    description: {name: zeta, url: "https://pub.dev"}
    source: hosted
    version: "1.0.0"
  alpha:
    dependency: "direct main"
    description: {name: alpha, url: "https://pub.dartlang.org"}
    source: hosted
    version: "2.0.0"
  internal:
    dependency: "direct main"
    description: {name: internal, url: "https://pub.corp.example"}
    source: hosted
    version: "3.0.0"
  local:
    dependency: "direct dev"
    description: {path: ../local, relative: true}
    source: path
    version: "0.0.1"
''';

  test('sorts direct dependencies first and classifies sources', () {
    final lockfile = const LockfileParser().parse(content, path: 'p.lock');
    expect(lockfile.packages.map((p) => p.name), <String>[
      'alpha',
      'internal',
      'local',
      'zeta',
    ]);
    final auditable = lockfile.auditable('https://pub.dev');
    expect(auditable.map((p) => p.name), <String>['alpha', 'zeta']);
    expect(lockfile.privatelyHosted('https://pub.dev').single.name, 'internal');
    expect(lockfile.unhosted.single.name, 'local');
  });

  test('treats the configured mirror as public', () {
    final lockfile = const LockfileParser().parse(content, path: 'p.lock');
    expect(lockfile.auditable('https://pub.corp.example'), hasLength(3));
  });

  test('accepts empty files and files without packages', () {
    expect(const LockfileParser().parse('', path: 'p').packages, isEmpty);
    expect(
      const LockfileParser().parse('sdks: {}', path: 'p').packages,
      isEmpty,
    );
  });

  test('reports malformed files as invalid input', () {
    for (final broken in <String>[
      '[1, 2]',
      'packages: [x]',
      'packages:\n  a: 1',
    ]) {
      expect(
        () => const LockfileParser().parse(broken, path: 'p'),
        throwsA(isA<InvalidInputException>()),
      );
    }
    expect(
      () => const LockfileParser().parseFile('/nonexistent/pubspec.lock'),
      throwsA(isA<InvalidInputException>()),
    );
  });
}
