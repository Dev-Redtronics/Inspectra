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

import 'package:inspectra/src/archive/archive_entry_kind.dart';
import 'package:inspectra/src/inspect/unicode_scanner.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:test/test.dart';

import '../support/entries.dart';

/// Tests the invisible and confusable character scanner.
void main() {
  /// Scans [content] as `lib/a.dart` and returns the rule ids.
  List<String> rulesFor(String content) => const UnicodeScanner()
      .scan([textEntry('lib/a.dart', content)])
      .map((f) => f.ruleId)
      .toList();

  test('detects Trojan Source bidi controls', () {
    expect(rulesFor('if (a) { /* \u202E } \u2066 */'), <String>[
      'BIDI_OVERRIDE',
    ]);
  });

  test('detects invisible characters but allows a leading BOM', () {
    expect(rulesFor('var a\u200B = 1;'), <String>['ZERO_WIDTH']);
    expect(rulesFor('\uFEFFvar a = 1;'), isEmpty);
  });

  test('sees supplementary plane carriers and tag characters', () {
    expect(rulesFor('x\u{E0100}'), <String>['PUA_CARRIER']);
    expect(rulesFor('x\u{E0041}\u{E0042}'), <String>['TAG_CHARACTER']);
    expect(rulesFor('flag: \u{1F3F4}\u{E0067}\u{E0062}\u{E007F}'), isEmpty);
  });

  test('allows emoji presentation selectors after symbols', () {
    expect(rulesFor("const heart = '\u2764\uFE0F';"), isEmpty);
    expect(rulesFor('a\uFE0F'), <String>['PUA_CARRIER']);
  });

  test('reports mixed script identifiers but not prose or symbols', () {
    expect(rulesFor('final p\u0430ssword = 1;'), <String>['HOMOGLYPH']);
    expect(rulesFor('// about 400 \u03BCs'), isEmpty);
    expect(
      rulesFor("const ru = '\u043F\u0440\u0438\u0432\u0435\u0442';"),
      isEmpty,
    );
  });

  test('skips binary files', () {
    final List<Finding> findings = const UnicodeScanner().scan([
      rawEntry(
        'a.png',
        ArchiveEntryKind.file,
        bytes: <int>[0, 0xE2, 0x80, 0xAE],
      ),
    ]);
    expect(findings, isEmpty);
  });
}
