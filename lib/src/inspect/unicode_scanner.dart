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

import '../archive/archive_entry.dart';
import '../model/finding.dart';
import '../model/finding_source.dart';
import '../model/severity.dart';
import '../model/source_location.dart';
import '../report/snippet_sanitizer.dart';

/// Detects invisible and confusable Unicode characters used to hide code.
///
/// Unlike scanners that iterate UTF-16 code units, this scanner iterates
/// code points, so supplementary plane characters such as variation selector
/// supplements and tag characters are seen. Rules:
///
/// * `BIDI_OVERRIDE` (CRITICAL): bidirectional controls enabling Trojan
///   Source attacks (CVE-2021-42574);
/// * `ZERO_WIDTH` (HIGH): invisible characters; a byte order mark at the
///   very start of a file is allowed;
/// * `PUA_CARRIER` (CRITICAL): variation selectors and private use
///   characters that can carry hidden payloads (GlassWorm); an emoji
///   presentation selector right after a symbol is allowed;
/// * `TAG_CHARACTER` (CRITICAL): Unicode tag characters used for ASCII
///   smuggling, except inside emoji flag sequences;
/// * `HOMOGLYPH` (HIGH): identifiers mixing Latin letters with Cyrillic or
///   Greek look-alikes or full width letters, outside of comments.
///
/// Each rule reports at most once per line.
final class UnicodeScanner {
  /// Creates a scanner.
  const UnicodeScanner();

  /// The names of bidirectional control characters.
  static const Map<int, String> _bidi = <int, String>{
    0x061C: 'ARABIC LETTER MARK',
    0x200E: 'LEFT-TO-RIGHT MARK',
    0x200F: 'RIGHT-TO-LEFT MARK',
    0x202A: 'LEFT-TO-RIGHT EMBEDDING',
    0x202B: 'RIGHT-TO-LEFT EMBEDDING',
    0x202C: 'POP DIRECTIONAL FORMATTING',
    0x202D: 'LEFT-TO-RIGHT OVERRIDE',
    0x202E: 'RIGHT-TO-LEFT OVERRIDE',
    0x2066: 'LEFT-TO-RIGHT ISOLATE',
    0x2067: 'RIGHT-TO-LEFT ISOLATE',
    0x2068: 'FIRST STRONG ISOLATE',
    0x2069: 'POP DIRECTIONAL ISOLATE',
  };

  /// The names of invisible characters.
  static const Map<int, String> _invisible = <int, String>{
    0x00AD: 'SOFT HYPHEN',
    0x034F: 'COMBINING GRAPHEME JOINER',
    0x180E: 'MONGOLIAN VOWEL SEPARATOR',
    0x200B: 'ZERO WIDTH SPACE',
    0x200C: 'ZERO WIDTH NON-JOINER',
    0x200D: 'ZERO WIDTH JOINER',
    0x2028: 'LINE SEPARATOR',
    0x2029: 'PARAGRAPH SEPARATOR',
    0x2060: 'WORD JOINER',
    0x2061: 'FUNCTION APPLICATION',
    0x2062: 'INVISIBLE TIMES',
    0x2063: 'INVISIBLE SEPARATOR',
    0x2064: 'INVISIBLE PLUS',
    0xFEFF: 'ZERO WIDTH NO-BREAK SPACE (BOM)',
  };

  /// The emoji presentation and text presentation selectors.
  static const Set<int> _presentationSelectors = <int>{0xFE0E, 0xFE0F};

  /// The waving black flag that starts emoji tag sequences.
  static const int _blackFlag = 0x1F3F4;

  /// Cyrillic and Greek letters that are visually identical to Latin ones.
  static const Set<int> _confusables = <int>{
    0x0391,
    0x0392,
    0x0395,
    0x0396,
    0x0397,
    0x0399,
    0x039A,
    0x039C,
    0x039D,
    0x039F,
    0x03A1,
    0x03A4,
    0x03A5,
    0x03A7,
    0x03B1,
    0x03B5,
    0x03B9,
    0x03BA,
    0x03BD,
    0x03BF,
    0x03C1,
    0x03C5,
    0x0405,
    0x0406,
    0x0408,
    0x0410,
    0x0412,
    0x0415,
    0x041A,
    0x041C,
    0x041D,
    0x041E,
    0x0420,
    0x0421,
    0x0422,
    0x0425,
    0x0430,
    0x0435,
    0x043E,
    0x0440,
    0x0441,
    0x0443,
    0x0445,
    0x0455,
    0x0456,
    0x0458,
    0x04BB,
    0x04CF,
    0x0501,
    0x051B,
    0x051D,
  };

  /// The pattern of identifier-like tokens.
  static final RegExp _token = RegExp(r'[\p{L}\p{N}_]+', unicode: true);

  /// Scans every text file of [entries]; binary files are skipped.
  ///
  /// Returns the findings, CRITICAL before HIGH.
  List<Finding> scan(List<ArchiveEntry> entries) {
    final findings = <Finding>[];
    for (final entry in entries.where((entry) => entry.isText)) {
      final lines = entry.text.split('\n');
      for (var index = 0; index < lines.length; index++) {
        findings.addAll(_scanLine(entry, lines[index], index + 1));
      }
    }
    return findings..sort((a, b) => a.severity.rank.compareTo(b.severity.rank));
  }

  /// Scans one [line] of [entry].
  ///
  /// Returns the findings of that line, at most one per rule.
  List<Finding> _scanLine(ArchiveEntry entry, String line, int lineNumber) {
    final found = <String, Finding>{};
    final runes = line.runes.toList();
    for (var position = 0; position < runes.length; position++) {
      final rune = runes[position];
      final previous = position == 0 ? 0 : runes[position - 1];
      final isFileStart = lineNumber == 1 && position == 0;
      final match = _classify(rune, previous, isFileStart, runes, position);
      if (match == null) {
        continue;
      }
      final (rule, severity, description) = match;
      found.putIfAbsent(
        rule,
        () => _finding(
          entry,
          line,
          lineNumber,
          rule,
          severity,
          description,
          rune,
        ),
      );
    }
    final isComment = entry.path.endsWith('.dart') && _isComment(line);
    final homoglyph = isComment ? null : _homoglyph(entry, line, lineNumber);
    if (homoglyph != null) {
      found[homoglyph.ruleId] = homoglyph;
    }
    return found.values.toList();
  }

  /// Classifies [rune], given the [previous] rune of the line.
  ///
  /// Returns the rule, severity and description, or `null` when the rune is
  /// harmless in its context.
  (String, Severity, String)? _classify(
    int rune,
    int previous,
    bool isFileStart,
    List<int> runes,
    int position,
  ) {
    final bidiName = _bidi[rune];
    if (bidiName != null) {
      return (
        'BIDI_OVERRIDE',
        Severity.critical,
        'Invisible bidi control character: $bidiName',
      );
    }
    final invisibleName = _invisible[rune];
    if (invisibleName != null && !(rune == 0xFEFF && isFileStart)) {
      return (
        'ZERO_WIDTH',
        Severity.high,
        'Invisible character: $invisibleName',
      );
    }
    if (_isCarrier(rune, previous)) {
      return (
        'PUA_CARRIER',
        Severity.critical,
        'Variation selector or private use character (potential payload '
            'carrier — GlassWorm pattern)',
      );
    }
    if (rune >= 0xE0000 && rune <= 0xE007F && !_inFlag(runes, position)) {
      return (
        'TAG_CHARACTER',
        Severity.critical,
        'Unicode tag character (invisible ASCII smuggling)',
      );
    }
    return null;
  }

  /// Whether [rune] is a variation selector or private use character that
  /// is not a legitimate emoji presentation selector after [previous].
  ///
  /// Returns `true` for potential payload carriers.
  bool _isCarrier(int rune, int previous) {
    final isSelector = rune >= 0xFE00 && rune <= 0xFE0F;
    final isSupplementSelector = rune >= 0xE0100 && rune <= 0xE01EF;
    final isPrivateUse =
        rune >= 0xE000 && rune <= 0xF8FF || rune >= 0xF0000 && rune <= 0x10FFFF;
    final isEmojiPresentation =
        _presentationSelectors.contains(rune) && previous >= 0x2000;
    if (isEmojiPresentation) {
      return false;
    }
    return isSelector || isSupplementSelector || isPrivateUse;
  }

  /// Whether the tag character at [position] belongs to an emoji flag
  /// sequence that starts with the black flag.
  ///
  /// Returns `true` inside a flag sequence.
  bool _inFlag(List<int> runes, int position) {
    for (var index = position - 1; index >= 0; index--) {
      final rune = runes[index];
      if (rune >= 0xE0000 && rune <= 0xE007F) {
        continue;
      }
      return rune == _blackFlag;
    }
    return false;
  }

  /// Whether [line] is a Dart comment line, where confusable letters are
  /// harmless prose.
  ///
  /// Returns `true` for comment lines.
  bool _isComment(String line) {
    final trimmed = line.trimLeft();
    return trimmed.startsWith('//') ||
        trimmed.startsWith('*') ||
        trimmed.startsWith('/*');
  }

  /// Finds the first identifier-like token of [line] that mixes Latin
  /// letters with Cyrillic, Greek or full width letters.
  ///
  /// Returns the finding, or `null`.
  Finding? _homoglyph(ArchiveEntry entry, String line, int lineNumber) {
    for (final match in _token.allMatches(line)) {
      final token = match[0] ?? '';
      final runes = token.runes;
      final hasLatin = runes.any(
        (r) => r >= 0x41 && r <= 0x5A || r >= 0x61 && r <= 0x7A,
      );
      final foreign = runes.where(_isConfusableScript).firstOrNull;
      if (hasLatin && foreign != null) {
        return _finding(
          entry,
          line,
          lineNumber,
          'HOMOGLYPH',
          Severity.high,
          'Confusable character in "$token": the identifier mixes Latin '
              'with another script',
          foreign,
        );
      }
    }
    return null;
  }

  /// Whether [rune] is a Cyrillic or Greek letter that renders like a Latin
  /// letter, or a full width Latin letter.
  ///
  /// Only true look-alikes count, so that technical symbols such as the
  /// Greek `μ` in `μs` are not reported.
  ///
  /// Returns `true` for confusable letters.
  bool _isConfusableScript(int rune) {
    final fullWidth = rune >= 0xFF21 && rune <= 0xFF5A;
    return fullWidth || _confusables.contains(rune);
  }

  /// Creates a finding for [rune] on [line].
  ///
  /// Returns the finding.
  Finding _finding(
    ArchiveEntry entry,
    String line,
    int lineNumber,
    String rule,
    Severity severity,
    String description,
    int rune,
  ) {
    final hex = rune.toRadixString(16).toUpperCase().padLeft(4, '0');
    return Finding(
      ruleId: rule,
      source: FindingSource.unicode,
      severity: severity,
      title: description,
      location: SourceLocation(entry.path, line: lineNumber),
      snippet: SnippetSanitizer.sanitize(line),
      attributes: <String, Object?>{'codepoint': 'U+$hex'},
    );
  }
}
