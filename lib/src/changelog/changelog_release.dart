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

import 'package:inspectra/src/changelog/changelog_changes.dart';

/// A release section of a changelog: a version, its date and its changes.
final class ChangelogRelease {
  /// Creates a release.
  ///
  /// [previousTag] is the release tag the changes are counted from, `null`
  /// for the first release, and [tag] the tag this release will get.
  const ChangelogRelease({
    required this.version,
    required this.date,
    required this.changes,
    required this.tag,
    this.previousTag,
  });

  /// The version, such as `1.2.0`.
  final String version;

  /// The release date as `YYYY-MM-DD`.
  final String date;

  /// The changes of the release.
  final ChangelogChanges changes;

  /// The tag of this release, such as `v1.2.0`.
  final String tag;

  /// The tag of the previous release, or `null` for the first release.
  final String? previousTag;
}
