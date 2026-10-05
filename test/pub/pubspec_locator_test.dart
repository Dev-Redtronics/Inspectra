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

import 'package:inspectra/src/pub/pubspec_locator.dart';
import 'package:test/test.dart';

/// Tests finding keys of a pubspec by its structure.
void main() {
  const content = '''
name: app
environment:
  sdk: ^3.6.0
  flutter: ">=3.27.0"
dependencies:
  flutter:
    sdk: flutter
  sdk: ^1.0.0
  path: ^1.9.0
dev_dependencies:
  path: ^1.9.0
''';
  final locator = PubspecLocator.parse(content, 'pubspec.yaml');

  test('finds a key in the section it belongs to', () {
    expect(locator.entry('environment', 'sdk').line, 3);
    expect(locator.entry('dependencies', 'sdk').line, 8);
    expect(locator.entry('dependencies', 'path').line, 9);
    expect(locator.entry('dev_dependencies', 'path').line, 11);
    expect(locator.topLevel('name').line, 1);
  });

  test('falls back to the section and then to the file', () {
    expect(locator.entry('dependencies', 'http').line, 5);
    expect(locator.entry('dependency_overrides', 'http').line, isNull);
    expect(locator.topLevel('publish_to').toString(), 'pubspec.yaml');
    expect(
      PubspecLocator.parse('- a list', 'x.yaml').topLevel('name').line,
      isNull,
    );
    expect(PubspecLocator.parse('a: [', 'x.yaml').topLevel('a').line, isNull);
  });
}
