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

import 'dart:io';

import 'package:args/args.dart';
import 'package:inspectra/src/changelog/changelog_document.dart';
import 'package:inspectra/src/changelog/changelog_heading.dart';
import 'package:inspectra/src/changelog/changelog_notes_report.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/inspectra_command.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/report/command_report.dart';

/// `inspectra changelog notes [version]`: prints the changelog section of
/// a release, for example as the description of a GitHub release.
final class ChangelogNotesCommand extends InspectraCommand {
  /// Creates the command.
  ChangelogNotesCommand(super.context);

  /// The command name.
  @override
  String get name => 'notes';

  /// The one line description.
  @override
  String get description =>
      'Print the changelog section of a release (default: the version of '
      'pubspec.yaml).';

  /// The positional arguments.
  @override
  String get invocation => 'inspectra changelog notes [version] [options]';

  /// Reads the section of the requested version.
  ///
  /// Returns the notes report.
  ///
  /// Throws an [InvalidUsageException] when no version is given or
  /// declared, and an [InvalidInputException] when the changelog is
  /// missing or has no text for the version.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    final String? version =
        results.rest.firstOrNull ?? session.pubspec()?.version;
    if (version == null) {
      throw const InvalidUsageException(
        'pubspec.yaml declares no version. Pass the version: '
        'inspectra changelog notes <version>',
      );
    }
    final String path = session.resolve(session.config.changelog.file);
    final String shown = session.display(path);
    final file = File(path);
    if (!file.existsSync()) {
      throw InvalidInputException('The changelog $shown does not exist.');
    }
    final document = ChangelogDocument.parse(file.readAsStringSync());
    final ChangelogHeading? heading = document.find(version);
    if (heading == null) {
      throw InvalidInputException(
        'The changelog $shown has no section for version $version.',
      );
    }
    final String notes = document.body(heading);
    if (notes.trim().isEmpty) {
      throw InvalidInputException(
        'The section of version $version in $shown is empty.',
      );
    }
    return ChangelogNotesReport(
      version: heading.version ?? version,
      date: heading.date,
      notes: notes,
    );
  }
}
