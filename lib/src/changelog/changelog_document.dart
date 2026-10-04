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

import 'package:inspectra/src/changelog/changelog_heading.dart';
import 'package:inspectra/src/changelog/changelog_values.dart';
import 'package:pub_semver/pub_semver.dart';

/// A changelog file in the Keep a Changelog layout: an introduction
/// followed by one level two section per release, newest first.
///
/// Headings inside fenced code blocks are ignored. The line endings of
/// the file are kept when a section is inserted.
final class ChangelogDocument {
  /// Creates a document from its [lines], the level two [headings] found in
  /// them, the one-based lines of every level one and two heading
  /// ([_boundaries]) and the [lineBreak] the file uses.
  const ChangelogDocument._(
    this.lines,
    this.headings,
    this._boundaries,
    this.lineBreak,
  );

  /// Parses the changelog [text].
  ///
  /// Returns the document.
  factory ChangelogDocument.parse(String text) {
    final lineBreak = text.contains('\r\n') ? '\r\n' : '\n';
    final List<String> lines = text.replaceAll('\r\n', '\n').split('\n');
    final headings = <ChangelogHeading>[];
    final boundaries = <int>[];
    String? fence;
    for (var index = 0; index < lines.length; index++) {
      final String line = lines[index];
      final RegExpMatch? fenceMatch = _fence.firstMatch(line);
      if (fenceMatch != null) {
        final String marker = fenceMatch[1] ?? '';
        final bool closes = fence != null && marker.startsWith(fence);
        fence = closes ? null : fence ?? marker;
        continue;
      }
      final bool heading = line.startsWith('# ') || line.startsWith('## ');
      if (fence != null || !heading) {
        continue;
      }
      boundaries.add(index + 1);
      if (line.startsWith('## ')) {
        headings.add(ChangelogHeading.parse(index + 1, line.substring(3)));
      }
    }
    return ChangelogDocument._(
      List<String>.unmodifiable(lines),
      List<ChangelogHeading>.unmodifiable(headings),
      List<int>.unmodifiable(boundaries),
      lineBreak,
    );
  }

  /// The introduction of a new changelog file.
  static const introduction =
      '# Changelog\n'
      '\n'
      'All notable changes to this project are documented in this file. The '
      'format follows\n'
      '[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the '
      'project adheres to\n'
      '[Semantic Versioning](https://semver.org/).\n';

  /// Matches the opening or closing line of a fenced code block.
  static final _fence = RegExp('^ {0,3}(`{3,}|~{3,})');

  /// Matches a link reference definition such as `[1.0.0]: https://...`.
  static final _linkDefinition = RegExp(r'^\[[^\]]+\]:\s*\S+');

  /// The lines of the file, without line breaks.
  final List<String> lines;

  /// The level two headings, in file order.
  final List<ChangelogHeading> headings;

  /// The one-based lines of the level one and two headings.
  final List<int> _boundaries;

  /// The line break of the file, `\n` or `\r\n`.
  final String lineBreak;

  /// Finds the section of [version]; versions are compared as semantic
  /// versions, so `[1.2.0]` and `v1.2.0` both match `1.2.0`.
  ///
  /// Returns the heading, or `null` when the version is not documented.
  ChangelogHeading? find(String version) {
    final Version? wanted = tryParseVersion(version);
    for (final ChangelogHeading heading in headings) {
      final String? candidate = heading.version;
      if (candidate == null) {
        continue;
      }
      final Version? parsed = tryParseVersion(candidate);
      final same = wanted != null && parsed != null
          ? wanted == parsed
          : candidate == version;
      if (same) {
        return heading;
      }
    }
    return null;
  }

  /// Returns the text of the section below [heading], without the heading,
  /// surrounding blank lines and trailing link reference definitions.
  String body(ChangelogHeading heading) {
    final int start = heading.line;
    final int end = _sectionEnd(start);
    final List<String> section = lines.sublist(start, end).toList();
    while (section.isNotEmpty && _isTrailer(section.last)) {
      section.removeLast();
    }
    while (section.isNotEmpty && section.first.trim().isEmpty) {
      section.removeAt(0);
    }
    return section.join('\n');
  }

  /// Inserts the release [section] above the newest release, below the
  /// introduction and an `Unreleased` section.
  ///
  /// Returns the new text of the file.
  String insert(String section) {
    final List<String> inserted = section.trimRight().split('\n');
    final int at =
        headings
            .where((heading) => !heading.unreleased)
            .map((heading) => heading.line - 1)
            .firstOrNull ??
        _endOfContent();
    final List<String> before = lines.sublist(0, at).toList();
    while (before.isNotEmpty && before.last.trim().isEmpty) {
      before.removeLast();
    }
    final List<String> after = lines.sublist(at);
    final result = <String>[
      ...before,
      if (before.isNotEmpty) '',
      ...inserted,
      '',
      ...after,
    ];
    while (result.length > 1 && result.last.trim().isEmpty) {
      result.removeLast();
    }
    return '${result.join(lineBreak)}$lineBreak';
  }

  /// Returns the index of the first line after the section whose heading
  /// is on line [headingLine]: the next level one or two heading or the
  /// end of the file.
  int _sectionEnd(int headingLine) {
    final int? next = _boundaries
        .where((line) => line > headingLine)
        .firstOrNull;
    return next == null ? lines.length : next - 1;
  }

  /// Returns the index after the last line that is not blank.
  int _endOfContent() {
    int end = lines.length;
    while (end > 0 && lines[end - 1].trim().isEmpty) {
      end--;
    }
    return end;
  }

  /// Whether [line] may end a section without belonging to its text.
  bool _isTrailer(String line) =>
      line.trim().isEmpty || _linkDefinition.hasMatch(line);
}
