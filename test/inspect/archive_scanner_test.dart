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
import 'package:inspectra/src/archive/archive_entry.dart';
import 'package:inspectra/src/archive/archive_entry_kind.dart';
import 'package:inspectra/src/inspect/archive_scanner.dart';
import 'package:test/test.dart';

import '../support/entries.dart';

/// Tests the structural archive checks.
void main() {
  /// Returns the rule ids reported for [entries].
  List<String> rulesFor(List<ArchiveEntry> entries) =>
      const ArchiveScanner().scan(entries).map((f) => f.ruleId).toList();

  test('detects traversal and absolute paths including Windows drives', () {
    expect(
      rulesFor([textEntry('lib/../../evil.dart', '')]),
      contains('PATH_TRAVERSAL'),
    );
    expect(rulesFor([textEntry('/etc/passwd', '')]), contains('ABSOLUTE_PATH'));
    expect(
      rulesFor([textEntry(r'C:\Windows\x.dll', '')]),
      contains('ABSOLUTE_PATH'),
    );
  });

  test('rates links by where they point', () {
    final escaping = const ArchiveScanner().scan([
      rawEntry('lib/x', ArchiveEntryKind.symlink, linkTarget: '../../etc'),
    ]);
    expect(escaping.single.severity, Severity.critical);
    final internal = const ArchiveScanner().scan([
      rawEntry('lib/x', ArchiveEntryKind.symlink, linkTarget: 'lib/y.dart'),
    ]);
    expect(internal.single.severity, Severity.high);
  });

  test('detects duplicates and case collisions', () {
    expect(
      rulesFor([textEntry('lib/a.dart', ''), textEntry('lib/a.dart', '')]),
      contains('DUPLICATE_ENTRY'),
    );
    expect(
      rulesFor([textEntry('lib/A.dart', ''), textEntry('lib/a.dart', '')]),
      contains('CASE_COLLISION'),
    );
  });

  test('detects native binaries by extension and magic number', () {
    expect(rulesFor([textEntry('lib/x.so', '')]), contains('NATIVE_BINARY'));
    expect(
      rulesFor([
        rawEntry(
          'lib/blob',
          ArchiveEntryKind.file,
          bytes: <int>[0x7F, 0x45, 0x4C, 0x46, 0],
        ),
      ]),
      contains('NATIVE_BINARY'),
    );
  });

  test('detects build hooks, hidden scripts, setuid bits and devices', () {
    expect(
      rulesFor([textEntry('hook/build.dart', '')]),
      contains('BUILD_HOOK'),
    );
    expect(
      rulesFor([textEntry('lib/.x.sh', '')]),
      contains('HIDDEN_EXECUTABLE'),
    );
    expect(
      rulesFor([textEntry('bin/x', '', mode: 0x9ED)]),
      contains('SETUID_BIT'),
    );
    expect(
      rulesFor([rawEntry('dev', ArchiveEntryKind.special)]),
      contains('SPECIAL_FILE'),
    );
  });

  test('accepts an ordinary package', () {
    expect(
      rulesFor([textEntry('lib/a.dart', ''), textEntry('pubspec.yaml', '')]),
      isEmpty,
    );
  });
}
