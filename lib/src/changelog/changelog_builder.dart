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

import 'package:inspectra/src/changelog/changelog_changes.dart';
import 'package:inspectra/src/changelog/changelog_entry.dart';
import 'package:inspectra/src/changelog/changelog_section.dart';
import 'package:inspectra/src/changelog/conventional_commit.dart';
import 'package:inspectra/src/changelog/version_bump.dart';
import 'package:inspectra/src/config/changelog_config.dart';

/// Groups parsed commits into the sections of a release and decides how
/// far they move the version.
///
/// * Every type is placed in the section the [config] maps it to; commits
///   that do not follow Conventional Commits go to its `unconventional`
///   section. Hidden commits are left out.
/// * Breaking changes are always listed, in their own section, whatever
///   their type.
/// * A commit that is reverted within the same range is left out together
///   with its revert, since neither reaches the release.
/// * The same change committed twice, as after a cherry-pick, is listed
///   once.
final class ChangelogBuilder {
  /// Creates a builder using the type mapping of [config].
  const ChangelogBuilder(this.config);

  /// The changelog settings.
  final ChangelogConfig config;

  /// Builds the changes of [commits], newest first.
  ///
  /// Returns the changes.
  ChangelogChanges build(List<ConventionalCommit> commits) {
    final List<ConventionalCommit> effective = _withoutReverted(commits);
    final sections = <ChangelogSection, List<ChangelogEntry>>{};
    final breaking = <ChangelogEntry>[];
    final seen = <String>{};
    VersionBump? bump;
    for (final commit in effective) {
      final ChangelogSection section = _sectionOf(commit);
      final bool listed = commit.breaking || section != ChangelogSection.hidden;
      final key =
          '${commit.breaking}|${section.id}|${commit.scope}|'
          '${commit.description}';
      if (!listed || !seen.add(key)) {
        continue;
      }
      final entry = ChangelogEntry(
        hash: commit.hash,
        scope: commit.scope,
        description: commit.description,
        breakingNotes: commit.breakingNotes,
      );
      bump = _larger(bump, _bumpOf(commit, section));
      if (commit.breaking) {
        breaking.add(entry);
        continue;
      }
      sections.putIfAbsent(section, () => <ChangelogEntry>[]).add(entry);
    }
    return ChangelogChanges(
      sections: <ChangelogSection, List<ChangelogEntry>>{
        for (final section in ChangelogSection.values)
          if (sections[section] case final List<ChangelogEntry> entries)
            section: List<ChangelogEntry>.unmodifiable(entries),
      },
      breaking: List<ChangelogEntry>.unmodifiable(breaking),
      bump: bump,
    );
  }

  /// Returns the section [commit] belongs in.
  ChangelogSection _sectionOf(ConventionalCommit commit) {
    final String? type = commit.type;
    if (type == null) {
      return config.unconventional;
    }
    return config.sectionOf(type);
  }

  /// Returns how far [commit], listed in [section], moves the version.
  VersionBump _bumpOf(ConventionalCommit commit, ChangelogSection section) {
    if (commit.breaking) {
      return VersionBump.major;
    }
    if (section == ChangelogSection.added) {
      return VersionBump.minor;
    }
    return VersionBump.patch;
  }

  /// Returns the larger of [current] and [candidate].
  VersionBump _larger(VersionBump? current, VersionBump candidate) {
    if (current == null || candidate.index > current.index) {
      return candidate;
    }
    return current;
  }

  /// Removes every commit that is reverted within [commits], together with
  /// the commit that reverts it.
  ///
  /// Returns the remaining commits in their order.
  List<ConventionalCommit> _withoutReverted(List<ConventionalCommit> commits) {
    final dropped = <String>{};
    for (final revert in commits) {
      for (final String reverted in revert.revertedHashes) {
        final ConventionalCommit? original = commits
            .where((commit) => commit.hash.toLowerCase().startsWith(reverted))
            .firstOrNull;
        final bool pending =
            original != null &&
            !dropped.contains(original.hash) &&
            !dropped.contains(revert.hash);
        if (pending) {
          dropped
            ..add(original.hash)
            ..add(revert.hash);
        }
      }
    }
    return <ConventionalCommit>[
      for (final commit in commits)
        if (!dropped.contains(commit.hash)) commit,
    ];
  }
}
