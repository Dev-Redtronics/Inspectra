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
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Tests reading the `style:` section of the configuration.
void main() {
  /// Parses the `style:` section [section] with the command line
  /// overrides [cli].
  StyleConfig parse(
    Map<String, Object?>? section, {
    Map<String, String> cli = const <String, String>{},
  }) => InspectraConfig.parse(
    <String, Object?>{'style': section},
    packageName: 'demo',
    overrides: ConfigOverrides(cli: cli),
  ).style;

  test('has defaults', () {
    final StyleConfig config = parse(null);
    expect(config.enabled, isFalse);
    expect(config.runOnBuild, isFalse);
    expect(config.failOnFindings, isTrue);
    expect(config.preset, StylePreset.recommended);
    expect(config.rules, isEmpty);
    expect(config.licenseHeader, isNull);
    expect(config.customRules, isEmpty);
    expect(config.include, FormatConfig.defaultInclude);
    expect(config.exclude, FormatConfig.defaultExclude);
    expect(config.runs('one_public_type_per_file'), isTrue);
    expect(config.runs('public_docs'), isFalse);
    expect(config.runs('no_else'), isFalse);
  });

  test('reads every key', () {
    final StyleConfig config = parse(<String, Object?>{
      'enabled': true,
      'run_on_build': true,
      'fail_on_findings': false,
      'preset': 'strict',
      'rules': <String, Object?>{'no_comments': false, 'no_print': true},
      'license_header': 'tool/header.txt',
      'custom_rules': <String>['tool/style_rules.dart'],
      'include': <String>['lib/**.dart'],
      'exclude': <String>['lib/gen/**'],
    });
    expect(config.enabled, isTrue);
    expect(config.runOnBuild, isTrue);
    expect(config.failOnFindings, isFalse);
    expect(config.preset, StylePreset.strict);
    expect(config.rules, <String, bool>{
      'no_comments': false,
      'no_print': true,
    });
    expect(config.runs('no_comments'), isFalse);
    expect(config.runs('no_else'), isTrue);
    expect(config.licenseHeader, 'tool/header.txt');
    expect(config.customRules, <String>['tool/style_rules.dart']);
    expect(config.include, <String>['lib/**.dart']);
    expect(config.exclude, <String>['lib/gen/**']);
  });

  test('takes overrides from the command line', () {
    final StyleConfig config = parse(
      null,
      cli: <String, String>{
        'style.preset': 'none',
        'style.rules.no_else': 'true',
      },
    );
    expect(config.preset, StylePreset.none);
    expect(config.runs('no_else'), isTrue);
    expect(config.runs('public_docs'), isFalse);
    final StyleConfig custom = parse(
      <String, Object?>{
        'custom_rules': <String>['tool/r.dart'],
      },
      cli: <String, String>{'style.rules.no_print': 'false'},
    );
    expect(custom.runs('no_print'), isFalse);
  });

  test('rejects unknown rules, bad ids and a header rule without header', () {
    /// Returns the message of parsing [section].
    String error(Map<String, Object?> section) {
      try {
        parse(section);
      } on InspectraConfigException catch (exception) {
        return '$exception';
      }
      return '';
    }

    expect(
      error(<String, Object?>{
        'rules': <String, Object?>{'no_print': true},
      }),
      allOf(contains('style.rules.no_print'), contains('Built-in rules:')),
    );
    expect(
      error(<String, Object?>{
        'custom_rules': <String>['tool/r.dart'],
        'rules': <String, Object?>{'NoPrint': true},
      }),
      contains('lower snake case'),
    );
    expect(
      error(<String, Object?>{
        'rules': <String, Object?>{'license_header': true},
      }),
      contains('needs a header template'),
    );
    expect(
      error(<String, Object?>{
        'rules': <String, Object?>{'no_else': 'yes'},
      }),
      contains('true or false'),
    );
    expect(error(<String, Object?>{'preset': 'loose'}), contains('strict'));
    expect(error(<String, Object?>{'unknown': 1}), contains('unknown option'));
  });

  test('describes a list or mapping of the wrong kind read from YAML', () {
    for (final (String yaml, String described) in <(String, String)>[
      ('style:\n  rules: [no_else]\n', 'got a list'),
      ('style:\n  preset: {strict: true}\n', 'got a mapping'),
    ]) {
      expect(
        () => InspectraConfig.parse(
          loadYaml(yaml) as Map<Object?, Object?>,
          packageName: 'demo',
        ),
        throwsA(
          isA<InspectraConfigException>().having(
            (error) => '$error',
            'message',
            contains(described),
          ),
        ),
      );
    }
  });
}
