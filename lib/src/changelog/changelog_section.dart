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

/// The section of a release a commit is listed in, following
/// [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
///
/// The values are declared in the order the sections appear in a release.
enum ChangelogSection {
  /// New features.
  added('added', 'Added'),

  /// Changes in existing functionality.
  changed('changed', 'Changed'),

  /// Features that will be removed in an upcoming release.
  deprecated('deprecated', 'Deprecated'),

  /// Features removed in this release.
  removed('removed', 'Removed'),

  /// Bug fixes.
  fixed('fixed', 'Fixed'),

  /// Fixed vulnerabilities.
  security('security', 'Security'),

  /// Commits that are left out of the changelog.
  hidden('hidden', 'Hidden');

  /// Creates a section with its configuration [id] and [heading].
  const ChangelogSection(this.id, this.heading);

  /// The name used in the configuration and in JSON reports.
  final String id;

  /// The heading of the section in the changelog.
  final String heading;

  /// Every section by its configuration [id].
  static final byId = <String, ChangelogSection>{
    for (final section in values) section.id: section,
  };
}
