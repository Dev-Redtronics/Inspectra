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

import 'package:inspectra/src/changelog/changelog_document.dart';
import 'package:inspectra/src/changelog/changelog_release.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';

/// Adds release sections to a changelog file.
final class ChangelogWriter {
  /// Creates a writer.
  const ChangelogWriter();

  /// Adds the section [markdown] of [release] to the changelog at [path],
  /// below its introduction and `Unreleased` section and above the newest
  /// release. A missing file is created with the Keep a Changelog
  /// introduction.
  ///
  /// Throws an [InvalidUsageException] when the changelog already has a
  /// section for the version, without changing the file, and an
  /// [UnavailableException] when the file cannot be read or written.
  void write(String path, ChangelogRelease release, String markdown) {
    final file = File(path);
    try {
      final String existing = file.existsSync()
          ? file.readAsStringSync()
          : ChangelogDocument.introduction;
      final document = ChangelogDocument.parse(existing);
      if (document.find(release.version) != null) {
        throw InvalidUsageException(
          '$path already has a section for version ${release.version}. '
          'Choose another version with --release.',
        );
      }
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(document.insert(markdown));
    } on FileSystemException catch (error) {
      throw UnavailableException(
        'Cannot update the changelog $path: ${error.message}',
      );
    }
  }
}
