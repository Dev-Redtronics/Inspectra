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

import 'package:inspectra/src/changelog/changelog_document.dart';
import 'package:inspectra/src/changelog/changelog_heading.dart';
import 'package:inspectra/src/changelog/changelog_values.dart';
import 'package:test/test.dart';

/// Tests reading, querying and extending changelog files.
void main() {
  const changelog = '''
# Changelog

Intro.

## [Unreleased]

- Pending.

## [1.1.0](https://example.com/1.1.0) - 2026-09-01

### Added

- Feature.

```markdown
## 9.9.9 inside a code block
```

## v1.0.0 (2026-01-01) [YANKED]

- First.

[1.1.0]: https://example.com/compare/v1.0.0...v1.1.0
''';

  group('ChangelogHeading', () {
    /// Parses the heading [text].
    ChangelogHeading parse(String text) => ChangelogHeading.parse(1, text);

    test('understands the Keep a Changelog and pub.dev forms', () {
      final cases = <String, (String?, String?)>{
        '1.2.0': ('1.2.0', null),
        '[1.2.0]': ('1.2.0', null),
        'v1.2.0': ('1.2.0', null),
        '1.2.0 - 2026-10-04': ('1.2.0', '2026-10-04'),
        '[1.2.0] – 2026-10-04': ('1.2.0', '2026-10-04'),
        '[1.2.0](https://x/y) - 2026-10-04 [YANKED]': ('1.2.0', '2026-10-04'),
        '1.2.0 (2026-10-04)': ('1.2.0', '2026-10-04'),
        '1.2.0 [YANKED]': ('1.2.0', null),
        '2.0.0-beta.1+build.5': ('2.0.0-beta.1+build.5', null),
      };
      for (final MapEntry<String, (String?, String?)> entry in cases.entries) {
        final ChangelogHeading heading = parse(entry.key);
        expect(heading.version, entry.value.$1, reason: entry.key);
        expect(heading.date, entry.value.$2, reason: entry.key);
        expect(heading.isRelease, isTrue);
      }
    });

    test('recognises Unreleased and other headings', () {
      expect(parse('Unreleased').unreleased, isTrue);
      expect(parse('[unreleased](https://x)').unreleased, isTrue);
      expect(parse('Notes').isRelease, isFalse);
      expect(parse('2026 roadmap').isRelease, isFalse);
    });
  });

  group('ChangelogDocument', () {
    final document = ChangelogDocument.parse(changelog);

    test('finds the release headings outside of code blocks', () {
      expect(
        document.headings.map((heading) => heading.text).toList(),
        <String>[
          '[Unreleased]',
          '[1.1.0](https://example.com/1.1.0) - 2026-09-01',
          'v1.0.0 (2026-01-01) [YANKED]',
        ],
      );
      expect(document.headings[1].line, 9);
    });

    test('finds sections by semantic version', () {
      expect(document.find('1.1.0')?.line, 9);
      expect(document.find('v1.0.0')?.date, '2026-01-01');
      expect(document.find('1.0.0+0'), isNull);
      expect(document.find('2.0.0'), isNull);
    });

    test('returns the text of a section', () {
      final String body = document.body(document.headings[1]);
      expect(body, startsWith('### Added\n\n- Feature.'));
      expect(body, contains('## 9.9.9 inside a code block'));
      expect(document.body(document.headings[2]), '- First.');
    });

    test('inserts a release below Unreleased and above the newest', () {
      final String text = document.insert('## 1.2.0 - 2026-10-04\n\n- New.\n');
      expect(
        text,
        contains(
          '- Pending.\n\n## 1.2.0 - 2026-10-04\n\n- New.\n\n'
          '## [1.1.0]',
        ),
      );
      expect(text, endsWith('v1.1.0\n'));
    });

    test('appends to a changelog without releases', () {
      final String text = ChangelogDocument.parse(
        ChangelogDocument.introduction,
      ).insert('## 1.0.0 - 2026-10-04\n\n- First.\n');
      expect(
        text,
        '${ChangelogDocument.introduction}\n'
        '## 1.0.0 - 2026-10-04\n\n- First.\n',
      );
      expect(
        ChangelogDocument.parse('').insert('## 1.0.0\n\n- x\n'),
        '## 1.0.0\n\n- x\n',
      );
    });

    test('keeps CRLF line endings', () {
      final String text = ChangelogDocument.parse(
        '# Changelog\r\n\r\n## 1.0.0\r\n\r\n- x\r\n',
      ).insert('## 1.1.0\n\n- y\n');
      expect(
        text,
        '# Changelog\r\n\r\n## 1.1.0\r\n\r\n- y\r\n\r\n## 1.0.0\r\n\r\n'
        '- x\r\n',
      );
    });
  });

  group('values', () {
    test('parses versions with an optional v', () {
      expect('${tryParseVersion('v1.2.3')}', '1.2.3');
      expect(tryParseVersion('1.2'), isNull);
    });

    test('accepts only existing dates in the form YYYY-MM-DD', () {
      expect(isIsoDate('2024-02-29'), isTrue);
      expect(isIsoDate('2026-02-29'), isFalse);
      expect(isIsoDate('2026-13-01'), isFalse);
      expect(isIsoDate('04.10.2026'), isFalse);
      expect(formatIsoDate(DateTime(2026, 3, 7)), '2026-03-07');
    });
  });
}
