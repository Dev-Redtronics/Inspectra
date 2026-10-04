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

import 'package:inspectra/src/changelog/changelog_entry.dart';
import 'package:inspectra/src/changelog/changelog_links.dart';
import 'package:inspectra/src/changelog/changelog_release.dart';
import 'package:inspectra/src/changelog/changelog_section.dart';
import 'package:inspectra/src/report/snippet_sanitizer.dart';

/// Renders a release as a Markdown section of a Keep a Changelog file.
///
/// ```markdown
/// ## 1.2.0 - 2026-10-04
///
/// ### Added
///
/// - **trivy:** scan container images ([1a2b3c4](https://...))
/// ```
///
/// Commit texts are untrusted: control, bidirectional and invisible
/// characters are made visible before they reach the file.
final class ChangelogMarkdown {
  /// Creates a renderer that links commits and the comparison with the
  /// previous release when [links] is given.
  const ChangelogMarkdown({this.links});

  /// The link builder, or `null` to render plain commit hashes.
  final ChangelogLinks? links;

  /// The heading of the section listing breaking changes.
  static const breakingHeading = 'Breaking changes';

  /// Renders [release].
  ///
  /// Returns the section, ending with a single line break.
  String render(ChangelogRelease release) {
    final out = StringBuffer()
      ..writeln('## ${release.version} - ${release.date}');
    final List<ChangelogEntry> breaking = release.changes.breaking;
    if (breaking.isNotEmpty) {
      _writeSection(out, breakingHeading, breaking, withNotes: true);
    }
    for (final MapEntry<ChangelogSection, List<ChangelogEntry>> section
        in release.changes.sections.entries) {
      _writeSection(out, section.key.heading, section.value, withNotes: false);
    }
    final String? comparison = _comparison(release);
    if (comparison != null) {
      out
        ..writeln()
        ..writeln(comparison);
    }
    return out.toString();
  }

  /// Writes the section [heading] listing [entries]; [withNotes] adds the
  /// breaking change notes below each entry.
  void _writeSection(
    StringBuffer out,
    String heading,
    List<ChangelogEntry> entries, {
    required bool withNotes,
  }) {
    out
      ..writeln()
      ..writeln('### $heading')
      ..writeln();
    for (final entry in entries) {
      out.writeln('- ${_entry(entry)}');
      if (!withNotes) {
        continue;
      }
      for (final String note in entry.breakingNotes) {
        out.writeln();
        for (final String line in note.split('\n')) {
          final String text = _clean(line);
          out.writeln(text.isEmpty ? '' : '  $text');
        }
      }
    }
  }

  /// Returns the text of [entry]: scope, description and commit.
  String _entry(ChangelogEntry entry) {
    final String? scope = entry.scope;
    final prefix = scope == null ? '' : '**${_clean(scope)}:** ';
    return '$prefix${_clean(entry.description)} (${_commit(entry)})';
  }

  /// Returns the commit reference of [entry], linked when possible.
  String _commit(ChangelogEntry entry) {
    final ChangelogLinks? builder = links;
    if (builder == null) {
      return '`${entry.shortHash}`';
    }
    return '[`${entry.shortHash}`](${builder.commit(entry.hash)})';
  }

  /// Returns the link comparing [release] with the previous release, or
  /// `null` when there is none or links are off.
  String? _comparison(ChangelogRelease release) {
    final ChangelogLinks? builder = links;
    final String? previous = release.previousTag;
    if (builder == null || previous == null) {
      return null;
    }
    final String url = builder.compare(previous, release.tag);
    return '[Compare $previous...${release.tag}]($url)';
  }

  /// Returns [text] on one line with unsafe characters made visible.
  String _clean(String text) => SnippetSanitizer.escape(text.trim());
}
