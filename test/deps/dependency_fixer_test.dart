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
import 'package:inspectra/src/deps/dependency_fixer.dart';
import 'package:inspectra/src/deps/pubspec_fix.dart';
import 'package:inspectra/src/pub/pubspec_parser.dart';
import 'package:test/test.dart';

/// Tests fixing pubspecs as the dependency policy requires.
void main() {
  /// Fixes [content] with [config].
  ///
  /// Returns the fix.
  PubspecFix fix(DependencyPolicyConfig config, String content) =>
      DependencyFixer(config).fix(
        content,
        const PubspecParser().parse(content, path: 'pubspec.yaml'),
      );

  const policy = DependencyPolicyConfig(
    enabled: true,
    requireUpperBound: true,
    devOnly: <String>['mockito', 'lints'],
    requirePublishTo: true,
  );

  test('applies every fix and keeps comments and order', () {
    final PubspecFix result = fix(policy, '''
# The app.
name: app # its name
description: An app.
dependencies:
  # networking
  http: ">=1.2.0" # keep me
  path: {version: ">=1.8.0"}
  mockito: ^5.4.0
  meta: ^1.10.0
dev_dependencies:
  test: ^1.25.0
''');
    expect(result.content, '''
# The app.
name: app # its name
publish_to: none
description: An app.
dependencies:
  # networking
  http: ^1.2.0 # keep me
  path: {version: ^1.8.0}
  meta: ^1.10.0
dev_dependencies:
  mockito: ^5.4.0
  test: ^1.25.0
''');
    expect(result.applied, <String>[
      'http: >=1.2.0 -> ^1.2.0',
      'path: >=1.8.0 -> ^1.8.0',
      'mockito: dependencies -> dev_dependencies',
      'publish_to: none',
    ]);
    final PubspecFix again = fix(policy, result.content);
    expect(again.changed, isFalse);
    expect(again.content, result.content);
  });

  test('creates dev_dependencies and keeps a duplicate once', () {
    final PubspecFix created = fix(
      policy,
      'name: app\npublish_to: none\ndependencies:\n  lints: ^5.0.0\n',
    );
    expect(created.content, contains('dev_dependencies:\n  lints: ^5.0.0\n'));
    final PubspecFix duplicate = fix(
      policy,
      'name: app\npublish_to: none\ndependencies:\n  lints: ^5.0.0\n'
      'dev_dependencies:\n  lints: ^5.0.0\n',
    );
    expect(RegExp('lints:').allMatches(duplicate.content), hasLength(1));
  });

  test('changes nothing the policy does not ask for', () {
    const content =
        'name: app\ndependencies:\n  http: ">=1.2.0"\n  mockito: ^5.4.0\n';
    final PubspecFix result = fix(
      const DependencyPolicyConfig(
        enabled: true,
        requirePublishTo: true,
        publishedPackages: <String>['app'],
      ),
      content,
    );
    expect(result.changed, isFalse);
    expect(result.content, content);
    expect(
      fix(policy, 'description: no name\r\n').content,
      'description: no name\r\n',
    );
    expect(
      fix(policy, 'name: app\r\nversion: 1.0.0\r\n').content,
      'name: app\r\npublish_to: none\r\nversion: 1.0.0\r\n',
    );
  });

  test('rewrites constraints in the configured style after bounding', () {
    const content = '''
name: app
dependencies:
  http: ^1.2.0 # networking
  path: ">=1.8.0"
  meta: 1.15.0
  odd: ">=1.0.0 <1.5.0"
  hosted:
    hosted: https://pub.corp
    version: ^2.0.0
''';
    final PubspecFix range = fix(
      const DependencyPolicyConfig(
        requireUpperBound: true,
        constraintStyle: ConstraintStyle.range,
      ),
      content,
    );
    expect(range.content, '''
name: app
dependencies:
  http: ">=1.2.0 <2.0.0" # networking
  path: ">=1.8.0 <2.0.0"
  meta: ">=1.15.0 <2.0.0"
  odd: ">=1.0.0 <1.5.0"
  hosted:
    hosted: https://pub.corp
    version: ">=2.0.0 <3.0.0"
''');
    expect(range.applied, contains('meta: 1.15.0 -> >=1.15.0 <2.0.0'));
    final PubspecFix caret = fix(
      const DependencyPolicyConfig(constraintStyle: ConstraintStyle.caret),
      range.content,
    );
    expect(caret.content, contains('http: ^1.2.0 # networking'));
    expect(caret.content, contains('odd: ">=1.0.0 <1.5.0"'));
    final PubspecFix pinned = fix(
      const DependencyPolicyConfig(constraintStyle: ConstraintStyle.pinned),
      content,
    );
    expect(pinned.changed, isFalse);
  });
}
