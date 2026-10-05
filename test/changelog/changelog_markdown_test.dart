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
import 'package:inspectra/src/changelog/changelog_changes.dart';
import 'package:inspectra/src/changelog/changelog_entry.dart';
import 'package:inspectra/src/changelog/changelog_links.dart';
import 'package:inspectra/src/changelog/changelog_markdown.dart';
import 'package:inspectra/src/changelog/changelog_release.dart';
import 'package:test/test.dart';

import '../support/fake_git.dart';

/// Tests rendering a release as Markdown.
void main() {
  const links = ChangelogLinks(
    repository: 'https://github.com/acme/demo',
    commitUrl: ChangelogConfig.defaultCommitUrl,
    compareUrl: ChangelogConfig.defaultCompareUrl,
  );

  final release = ChangelogRelease(
    version: '1.2.0',
    date: '2026-10-04',
    tag: 'v1.2.0',
    previousTag: 'v1.1.0',
    changes: ChangelogChanges(
      sections: <ChangelogSection, List<ChangelogEntry>>{
        ChangelogSection.added: <ChangelogEntry>[
          ChangelogEntry(
            hash: hashOf(1),
            scope: 'trivy',
            description: 'scan images',
          ),
        ],
        ChangelogSection.fixed: <ChangelogEntry>[
          ChangelogEntry(hash: hashOf(2), description: 'handle empty files'),
        ],
      },
      breaking: <ChangelogEntry>[
        ChangelogEntry(
          hash: hashOf(3),
          scope: 'cli',
          description: 'rename --out',
          breakingNotes: const <String>['Use --output.\n\nScripts break.'],
        ),
      ],
      bump: VersionBump.minor,
    ),
  );

  test('renders the Keep a Changelog layout with links', () {
    const repository = 'https://github.com/acme/demo';

    /// Returns the linked reference of the commit [seed].
    String commit(int seed) =>
        '[`${hashOf(seed).substring(0, 7)}`]($repository/commit/${hashOf(seed)})';

    final lines = <String>[
      '## 1.2.0 - 2026-10-04',
      '',
      '### Breaking changes',
      '',
      '- **cli:** rename --out (${commit(3)})',
      '',
      '  Use --output.',
      '',
      '  Scripts break.',
      '',
      '### Added',
      '',
      '- **trivy:** scan images (${commit(1)})',
      '',
      '### Fixed',
      '',
      '- handle empty files (${commit(2)})',
      '',
      '[Compare v1.1.0...v1.2.0]($repository/compare/v1.1.0...v1.2.0)',
    ];
    expect(
      const ChangelogMarkdown(links: links).render(release),
      '${lines.join('\n')}\n',
    );
  });

  test('renders plain hashes without links', () {
    final String markdown = const ChangelogMarkdown().render(release);
    expect(markdown, contains('- handle empty files (`2cccccc`)'));
    expect(markdown, isNot(contains('Compare')));
    expect(markdown, isNot(contains('https://')));
  });

  test('makes control and bidirectional characters visible', () {
    final unsafe = ChangelogRelease(
      version: '1.0.0',
      date: '2026-10-04',
      tag: 'v1.0.0',
      changes: ChangelogChanges(
        sections: <ChangelogSection, List<ChangelogEntry>>{
          ChangelogSection.fixed: <ChangelogEntry>[
            ChangelogEntry(
              hash: hashOf(1),
              scope: 'a\u202Eb',
              description: 'x\u001b[31my',
            ),
          ],
        },
        breaking: const <ChangelogEntry>[],
        bump: VersionBump.patch,
      ),
    );
    final String markdown = const ChangelogMarkdown().render(unsafe);
    expect(markdown, contains(r'**a\u{202E}b:** x\u{001B}[31my'));
  });

  group('ChangelogLinks', () {
    test('normalises web repository URLs and rejects others', () {
      expect(
        ChangelogLinks.normalizeRepository(' https://github.com/a/b.git/ '),
        'https://github.com/a/b',
      );
      expect(
        ChangelogLinks.normalizeRepository('http://git.example.com/a'),
        'http://git.example.com/a',
      );
      expect(ChangelogLinks.normalizeRepository(null), isNull);
      expect(ChangelogLinks.normalizeRepository('git@github.com:a/b'), isNull);
      expect(ChangelogLinks.normalizeRepository('javascript:x'), isNull);
      expect(ChangelogLinks.normalizeRepository('https://'), isNull);
    });

    test('fills the templates and encodes the values', () {
      const gitlab = ChangelogLinks(
        repository: 'https://gitlab.com/a/b',
        commitUrl: '{repository}/-/commit/{hash}',
        compareUrl: '{repository}/-/compare/{from}...{to}',
      );
      expect(gitlab.commit('abc'), 'https://gitlab.com/a/b/-/commit/abc');
      expect(
        gitlab.compare('release/1.0', 'v2'),
        'https://gitlab.com/a/b/-/compare/release%2F1.0...v2',
      );
    });
  });
}
