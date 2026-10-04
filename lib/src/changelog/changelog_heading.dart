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

/// A level two heading of a changelog, which starts a release section.
///
/// The accepted forms are those of Keep a Changelog and of pub.dev:
/// `## 1.2.0`, `## [1.2.0]`, `## [1.2.0](url)`, `## v1.2.0`, followed
/// optionally by ` - 2026-10-04` or ` (2026-10-04)` and ` [YANKED]`, and
/// `## Unreleased` or `## [Unreleased]`.
final class ChangelogHeading {
  /// Creates a heading found on the one-based [line] with the text after
  /// `## `.
  const ChangelogHeading({
    required this.line,
    required this.text,
    this.version,
    this.date,
    this.unreleased = false,
  });

  /// Parses the heading [text] found on [line].
  ///
  /// Returns the heading; its [version] is `null` when [text] is neither a
  /// version nor `Unreleased`.
  factory ChangelogHeading.parse(int line, String text) {
    final String trimmed = text.trim();
    if (_unreleased.hasMatch(trimmed)) {
      return ChangelogHeading(line: line, text: trimmed, unreleased: true);
    }
    final RegExpMatch? match = _release.firstMatch(trimmed);
    if (match == null) {
      return ChangelogHeading(line: line, text: trimmed);
    }
    final String rest = (match[2] ?? '').trim();
    final RegExpMatch? dated = _date.firstMatch(rest);
    final bool understood = rest.isEmpty || _yanked.hasMatch(rest);
    if (dated == null && !understood) {
      return ChangelogHeading(line: line, text: trimmed);
    }
    return ChangelogHeading(
      line: line,
      text: trimmed,
      version: match[1],
      date: dated?[1] ?? dated?[2],
    );
  }

  /// Matches `Unreleased`, optionally in brackets and linked.
  static final _unreleased = RegExp(
    r'^\[?unreleased\]?(?:\([^)]*\))?$',
    caseSensitive: false,
  );

  /// Matches a version, optionally in brackets, linked or prefixed with
  /// `v`, and captures the version and the rest of the heading.
  static final _release = RegExp(
    r'^\[?v?(\d[^\]\s()]*)\]?(?:\([^)\s]*\))?(.*)$',
  );

  /// Matches the date after a version, `- 2026-10-04` or `(2026-10-04)`,
  /// optionally followed by `[YANKED]`.
  static final _date = RegExp(
    r'^(?:[-–—]\s*(\S+)|\((\S+)\))(?:\s+\[YANKED\])?$',
    caseSensitive: false,
  );

  /// Matches a lone `[YANKED]` marker.
  static final _yanked = RegExp(r'^\[YANKED\]$', caseSensitive: false);

  /// The one-based line number.
  final int line;

  /// The heading text after `## `.
  final String text;

  /// The version as written, or `null` for `Unreleased` and for headings
  /// that are not release headings.
  final String? version;

  /// The release date as written, if any.
  final String? date;

  /// Whether this is the `Unreleased` section.
  final bool unreleased;

  /// Whether this is a release or `Unreleased` heading.
  bool get isRelease => unreleased || version != null;
}
