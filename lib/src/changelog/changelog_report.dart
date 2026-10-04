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

import 'package:inspectra/src/changelog/changelog_release.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/command_report.dart';

/// The report of `changelog generate`.
///
/// The text output is the Markdown section itself, so that it can be
/// redirected into a file or a release description; after `--write` it
/// confirms where the section was added.
final class ChangelogReport implements CommandReport {
  /// Creates the report of [release], rendered as [markdown]; [written] is
  /// the changelog the section was added to, if any.
  const ChangelogReport({
    required this.release,
    required this.markdown,
    this.written,
  });

  /// The generated release.
  final ChangelogRelease release;

  /// The release section as Markdown.
  final String markdown;

  /// The changelog the section was added to, or `null` when it was only
  /// printed.
  final String? written;

  /// Whether there is nothing to release.
  bool get isEmpty => release.changes.isEmpty;

  /// The name of the command.
  @override
  String get command => 'changelog generate';

  /// Generating a changelog never reports findings.
  @override
  List<Finding> get findings => const <Finding>[];

  /// Generating a changelog never fails because of findings.
  ///
  /// Returns `false`.
  @override
  bool isFailing(Severity threshold) => false;

  /// Builds the JSON body.
  ///
  /// Returns the JSON body.
  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'version': isEmpty ? null : release.version,
    'tag': isEmpty ? null : release.tag,
    'previous_tag': release.previousTag,
    'bump': release.changes.bump?.id,
    'date': release.date,
    'changes': release.changes.toJson(),
    'markdown': isEmpty ? null : markdown,
    'written': written,
  };

  /// Writes the Markdown section, or a confirmation after `--write`.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    final String? previous = release.previousTag;
    if (isEmpty) {
      out.writeln(
        previous == null
            ? 'No changes to release.'
            : 'No changes to release since $previous.',
      );
      return;
    }
    final String? file = written;
    if (file == null) {
      out.write(markdown);
      return;
    }
    final int count = release.changes.length;
    out.writeln(
      style.green(
        '✔ Version ${release.version} added to $file '
        '($count change${count == 1 ? '' : 's'}).',
      ),
    );
  }
}
