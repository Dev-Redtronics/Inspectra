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

/// Tests reading the `changelog:` section of the configuration.
void main() {
  /// Parses the `changelog:` section [section] with the command line
  /// overrides [cli].
  ChangelogConfig parse(
    Map<String, Object?>? section, {
    Map<String, String> cli = const <String, String>{},
  }) => InspectraConfig.parse(
    <String, Object?>{'changelog': section},
    packageName: 'demo',
    overrides: ConfigOverrides(cli: cli),
  ).changelog;

  test('has defaults that need no configuration', () {
    final ChangelogConfig config = parse(null);
    expect(config.enabled, isFalse);
    expect(config.file, 'CHANGELOG.md');
    expect(config.tagPrefix, 'v');
    expect(config.unconventional, ChangelogSection.hidden);
    expect(config.repository, isNull);
    expect(config.sectionOf('feat'), ChangelogSection.added);
    expect(config.sectionOf('FIX'), ChangelogSection.fixed);
    expect(config.sectionOf('unknown'), ChangelogSection.hidden);
  });

  test('reads every key', () {
    final ChangelogConfig config = parse(<String, Object?>{
      'enabled': true,
      'file': 'doc/CHANGES.md',
      'tag_prefix': '',
      'types': <String, Object?>{
        'docs': 'changed',
        'Deps': 'security',
        'feat': null,
      },
      'unconventional': 'changed',
      'repository': 'https://gitlab.com/a/b',
      'commit_url': '{repository}/-/commit/{hash}',
      'compare_url': '{repository}/-/compare/{from}...{to}',
    });
    expect(config.enabled, isTrue);
    expect(config.file, 'doc/CHANGES.md');
    expect(config.tagPrefix, '');
    expect(config.sectionOf('docs'), ChangelogSection.changed);
    expect(config.sectionOf('deps'), ChangelogSection.security);
    expect(config.sectionOf('feat'), ChangelogSection.added);
    expect(config.unconventional, ChangelogSection.changed);
    expect(config.repository, 'https://gitlab.com/a/b');
    expect(config.commitUrl, '{repository}/-/commit/{hash}');
  });

  test('takes overrides from the command line', () {
    final ChangelogConfig config = parse(
      <String, Object?>{'tag_prefix': ''},
      cli: <String, String>{
        'changelog.types.fix': 'hidden',
        'changelog.tag_prefix': 'release-',
        'changelog.enabled': 'true',
      },
    );
    expect(config.sectionOf('fix'), ChangelogSection.hidden);
    expect(config.tagPrefix, 'release-');
    expect(config.enabled, isTrue);
  });

  test('rejects unknown keys, sections and incomplete templates', () {
    expect(
      () => parse(<String, Object?>{'unknown': 1}),
      throwsA(isA<InspectraConfigException>()),
    );
    expect(
      () => parse(<String, Object?>{
        'types': <String, Object?>{'feat': 'features'},
      }),
      throwsA(
        isA<InspectraConfigException>().having(
          (error) => '$error',
          'message',
          contains('changelog.types.feat'),
        ),
      ),
    );
    expect(
      () => parse(<String, Object?>{'commit_url': 'https://x/commit'}),
      throwsA(
        isA<InspectraConfigException>().having(
          (error) => '$error',
          'message',
          contains('{hash}'),
        ),
      ),
    );
    expect(
      () => parse(<String, Object?>{'types': 'feat'}),
      throwsA(isA<InspectraConfigException>()),
    );
  });
}
