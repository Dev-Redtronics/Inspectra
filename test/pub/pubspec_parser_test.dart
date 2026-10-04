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
import 'package:inspectra/src/pub/dependency_kind.dart';
import 'package:inspectra/src/pub/dependency_spec.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/pub/pubspec_parser.dart';
import 'package:test/test.dart';

/// Tests `pubspec.yaml` parsing.
void main() {
  test('understands every dependency notation', () {
    final Pubspec pubspec = const PubspecParser().parse('''
name: app
environment:
  sdk: ^3.5.0
dependencies:
  plain: ^1.0.0
  bare:
  short_git:
    git: https://github.com/x/y.git
  long_git:
    git: {url: https://github.com/x/z.git, ref: v1.0.0}
  local: {path: ../local}
  hosted: {hosted: https://pub.corp, version: ^2.0.0}
  flutter: {sdk: flutter}
''', path: 'pubspec.yaml');
    final Map<String, DependencySpec> deps = pubspec.dependencies;
    expect(deps['plain']!.constraint, '^1.0.0');
    expect(deps['bare']!.constraint, isNull);
    expect(deps['short_git']!.kind, DependencyKind.git);
    expect(deps['short_git']!.gitUrl, 'https://github.com/x/y.git');
    expect(deps['long_git']!.gitRef, 'v1.0.0');
    expect(deps['local']!.kind, DependencyKind.path);
    expect(deps['hosted']!.hostedUrl, 'https://pub.corp');
    expect(pubspec.isFlutterProject, isTrue);
  });

  test('detects Flutter through environment.flutter', () {
    final Pubspec pubspec = const PubspecParser().parse(
      'name: a\nenvironment:\n  flutter: ">=3.0.0"\n',
      path: 'p',
    );
    expect(pubspec.isFlutterProject, isTrue);
  });

  test('reports malformed files as invalid input', () {
    expect(
      () => const PubspecParser().parse('dependencies: [a]', path: 'p'),
      throwsA(isA<InvalidInputException>()),
    );
    expect(
      () => const PubspecParser().parse('a: [', path: 'p'),
      throwsA(isA<InvalidInputException>()),
    );
  });
}
