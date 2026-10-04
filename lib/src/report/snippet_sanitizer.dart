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

/// Makes untrusted text safe to print in a terminal or embed in a report.
///
/// Source excerpts of inspected packages can contain bidirectional overrides,
/// zero width characters or raw escape sequences. Printed verbatim they would
/// reorder or hide the very text a reviewer needs to see, or even control the
/// terminal. Every such character is replaced by a visible `\u{XXXX}`
/// notation.
final class SnippetSanitizer {
  /// Prevents instantiation; this type only offers static helpers.
  const SnippetSanitizer._();

  /// The maximum length of a sanitised snippet.
  static const maxLength = 160;

  /// Sanitises [text] and truncates it to [maxLength] characters.
  ///
  /// Returns the printable text.
  static String sanitize(String text) {
    final String result = escape(text).trim();
    if (result.length <= maxLength) {
      return result;
    }
    return '${result.substring(0, maxLength)}…';
  }

  /// Replaces every unsafe character of [text] by its visible notation,
  /// without trimming or truncating it, for text such as commit messages
  /// that is shown in full.
  ///
  /// Returns the printable text.
  static String escape(String text) {
    final buffer = StringBuffer();
    for (final int rune in text.runes) {
      buffer.write(_isUnsafe(rune) ? _escape(rune) : String.fromCharCode(rune));
    }
    return buffer.toString();
  }

  /// Whether [rune] must not be printed verbatim.
  ///
  /// Returns `true` for control characters, bidirectional formatting,
  /// invisible characters, variation selectors, tag characters and private
  /// use code points.
  static bool _isUnsafe(int rune) {
    final bool isControl = rune < 0x20 && rune != 0x09 || rune == 0x7F;
    final bool isC1 = rune >= 0x80 && rune <= 0x9F;
    final bool isFormat =
        rune == 0x00AD ||
        rune == 0x061C ||
        rune == 0x180E ||
        rune >= 0x200B && rune <= 0x200F ||
        rune >= 0x2028 && rune <= 0x202E ||
        rune >= 0x2060 && rune <= 0x206F ||
        rune == 0xFEFF;
    final bool isSelector =
        rune >= 0xFE00 && rune <= 0xFE0F || rune >= 0xE0000 && rune <= 0xE0FFF;
    final bool isPrivateUse =
        rune >= 0xE000 && rune <= 0xF8FF || rune >= 0xF0000;
    return isControl || isC1 || isFormat || isSelector || isPrivateUse;
  }

  /// Formats [rune] as `\u{XXXX}`.
  ///
  /// Returns the escaped notation.
  static String _escape(int rune) {
    final String hex = rune.toRadixString(16).toUpperCase().padLeft(4, '0');
    return '\\u{$hex}';
  }
}
