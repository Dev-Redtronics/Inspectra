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

/// One line of a changelog, describing one commit.
final class ChangelogEntry {
  /// Creates an entry for the commit [hash].
  const ChangelogEntry({
    required this.hash,
    required this.description,
    this.scope,
    this.breakingNotes = const <String>[],
  });

  /// The full object name of the commit.
  final String hash;

  /// The scope of the commit, if any.
  final String? scope;

  /// What changed.
  final String description;

  /// The explanations of a breaking change, from the commit's footers.
  final List<String> breakingNotes;

  /// The abbreviated object name shown in changelogs.
  String get shortHash => hash.length > 7 ? hash.substring(0, 7) : hash;

  /// Serialises the entry for JSON reports.
  ///
  /// Returns the JSON object.
  Map<String, Object?> toJson() => <String, Object?>{
    'hash': hash,
    'scope': scope,
    'description': description,
    if (breakingNotes.isNotEmpty) 'breaking_notes': breakingNotes,
  };
}
