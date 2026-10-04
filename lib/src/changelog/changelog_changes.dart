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
import 'package:inspectra/src/changelog/changelog_section.dart';
import 'package:inspectra/src/changelog/version_bump.dart';

/// The changes of one release, grouped into the sections of Keep a
/// Changelog.
final class ChangelogChanges {
  /// Creates the changes.
  ///
  /// [sections] holds the entries of every visible section, [breaking] the
  /// breaking changes, which are listed in their own section only, and
  /// [bump] how far they move the version.
  const ChangelogChanges({
    required this.sections,
    required this.breaking,
    required this.bump,
  });

  /// The entries of each section, without the hidden section.
  final Map<ChangelogSection, List<ChangelogEntry>> sections;

  /// The breaking changes.
  final List<ChangelogEntry> breaking;

  /// How far the changes move the version, or `null` when there is
  /// nothing to release.
  final VersionBump? bump;

  /// The number of entries.
  int get length =>
      breaking.length +
      sections.values.fold(0, (sum, entries) => sum + entries.length);

  /// Whether there is nothing to release.
  bool get isEmpty => length == 0;

  /// Serialises the changes for JSON reports.
  ///
  /// Returns the JSON object.
  Map<String, Object?> toJson() => <String, Object?>{
    'breaking': <Map<String, Object?>>[
      for (final entry in breaking) entry.toJson(),
    ],
    'sections': <String, Object?>{
      for (final MapEntry<ChangelogSection, List<ChangelogEntry>> section
          in sections.entries)
        section.key.id: <Map<String, Object?>>[
          for (final entry in section.value) entry.toJson(),
        ],
    },
  };
}
