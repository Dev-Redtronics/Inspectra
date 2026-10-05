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
import 'package:inspectra/src/changelog/changelog_builder.dart';
import 'package:inspectra/src/changelog/changelog_changes.dart';
import 'package:inspectra/src/changelog/changelog_entry.dart';
import 'package:inspectra/src/changelog/conventional_commit_parser.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../support/fake_git.dart';

/// Tests grouping commits into the sections of a release.
void main() {
  const parser = ConventionalCommitParser();

  /// Parses [messages] as commits, newest first, with hashes 1, 2, ...
  List<ConventionalCommit> commits(List<String> messages) =>
      <ConventionalCommit>[
        for (var index = 0; index < messages.length; index++)
          parser.parse(
            GitCommit(hash: hashOf(index + 1), message: messages[index]),
          ),
      ];

  /// Builds the changes of [messages] with [config].
  ChangelogChanges build(
    List<String> messages, {
    ChangelogConfig config = const ChangelogConfig(),
  }) => ChangelogBuilder(config).build(commits(messages));

  /// Returns the descriptions of the entries of [section] in [changes].
  List<String> descriptions(
    ChangelogChanges changes,
    ChangelogSection section,
  ) => <String>[
    for (final ChangelogEntry entry
        in changes.sections[section] ?? const <ChangelogEntry>[])
      entry.description,
  ];

  test('maps the types to the Keep a Changelog sections', () {
    final ChangelogChanges changes = build(<String>[
      'feat: a',
      'fix: b',
      'perf: c',
      'refactor: d',
      'deprecate: e',
      'remove: f',
      'security: g',
      'docs: hidden',
      'chore: hidden',
      'ci: hidden',
      'wip: unknown types are hidden',
      'Update README',
    ]);
    expect(descriptions(changes, ChangelogSection.added), <String>['a']);
    expect(descriptions(changes, ChangelogSection.fixed), <String>['b']);
    expect(descriptions(changes, ChangelogSection.changed), <String>['c', 'd']);
    expect(descriptions(changes, ChangelogSection.deprecated), <String>['e']);
    expect(descriptions(changes, ChangelogSection.removed), <String>['f']);
    expect(descriptions(changes, ChangelogSection.security), <String>['g']);
    expect(changes.sections.keys, isNot(contains(ChangelogSection.hidden)));
    expect(changes.sections.keys.toList(), <ChangelogSection>[
      ChangelogSection.added,
      ChangelogSection.changed,
      ChangelogSection.deprecated,
      ChangelogSection.removed,
      ChangelogSection.fixed,
      ChangelogSection.security,
    ]);
    expect(changes.length, 7);
    expect(changes.bump, VersionBump.minor);
  });

  test('lists breaking changes on their own, whatever their type', () {
    final ChangelogChanges changes = build(<String>[
      'ci!: require Dart 3.13',
      'fix: a',
    ]);
    expect(changes.breaking.single.description, 'require Dart 3.13');
    expect(descriptions(changes, ChangelogSection.fixed), <String>['a']);
    expect(changes.bump, VersionBump.major);
    expect(changes.toJson()['breaking'], hasLength(1));
  });

  test('suggests a patch for fixes and nothing for hidden commits', () {
    expect(build(<String>['fix: a', 'docs: b']).bump, VersionBump.patch);
    final ChangelogChanges hidden = build(<String>['docs: a', 'test: b']);
    expect(hidden.isEmpty, isTrue);
    expect(hidden.bump, isNull);
  });

  test('follows the configured mapping', () {
    final config = ChangelogConfig(
      types: <String, ChangelogSection>{
        for (final MapEntry<String, ChangelogSection> type
            in ChangelogConfig.defaultTypes.entries)
          type.key: type.value,
        'docs': ChangelogSection.changed,
        'fix': ChangelogSection.hidden,
      },
      unconventional: ChangelogSection.changed,
    );
    final ChangelogChanges changes = build(<String>[
      'docs: a',
      'fix: b',
      'Update README',
    ], config: config);
    expect(descriptions(changes, ChangelogSection.changed), <String>[
      'a',
      'Update README',
    ]);
    expect(changes.sections[ChangelogSection.fixed], isNull);
  });

  test('drops commits reverted in the same range with their revert', () {
    final ChangelogChanges changes = build(<String>[
      'Revert "feat: b"\n\nThis reverts commit ${hashOf(3)}.',
      'Revert "feat: outside"\n\nThis reverts commit ${hashOf(99)}.',
      'feat: b',
      'feat: a',
    ]);
    expect(descriptions(changes, ChangelogSection.added), <String>['a']);
    expect(descriptions(changes, ChangelogSection.changed), <String>[
      'Revert "outside"',
    ]);
  });

  test('lists the same change once', () {
    final ChangelogChanges changes = build(<String>[
      'fix(cli): a',
      'fix(cli): a',
      'fix(api): a',
    ]);
    expect(changes.sections[ChangelogSection.fixed], hasLength(2));
    final Map<String, Object?> json = changes.toJson();
    final sections = json['sections']! as Map<String, Object?>;
    expect(sections.keys, <String>['fixed']);
  });

  group('VersionBump', () {
    /// Applies [bump] to [version].
    String apply(VersionBump bump, String version) =>
        '${bump.apply(Version.parse(version))}';

    test('follows Semantic Versioning from 1.0.0 on', () {
      expect(apply(VersionBump.major, '1.4.2'), '2.0.0');
      expect(apply(VersionBump.minor, '1.4.2'), '1.5.0');
      expect(apply(VersionBump.patch, '1.4.2'), '1.4.3');
    });

    test('treats minor versions as breaking before 1.0.0', () {
      expect(apply(VersionBump.major, '0.4.2'), '0.5.0');
      expect(apply(VersionBump.minor, '0.4.2'), '0.4.3');
      expect(apply(VersionBump.patch, '0.4.2'), '0.4.3');
    });

    test('releases a pre-release', () {
      expect(apply(VersionBump.major, '2.0.0-beta.1'), '2.0.0');
      expect(apply(VersionBump.patch, '1.2.3-rc.1'), '1.2.3');
    });
  });
}
