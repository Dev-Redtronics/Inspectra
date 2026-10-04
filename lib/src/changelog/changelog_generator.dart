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

import 'package:inspectra/src/changelog/changelog_builder.dart';
import 'package:inspectra/src/changelog/changelog_changes.dart';
import 'package:inspectra/src/changelog/changelog_release.dart';
import 'package:inspectra/src/changelog/changelog_values.dart';
import 'package:inspectra/src/changelog/conventional_commit.dart';
import 'package:inspectra/src/changelog/conventional_commit_parser.dart';
import 'package:inspectra/src/changelog/git_commit.dart';
import 'package:inspectra/src/changelog/git_history.dart';
import 'package:inspectra/src/changelog/release_tag.dart';
import 'package:inspectra/src/changelog/version_bump.dart';
import 'package:inspectra/src/config/changelog_config.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:pub_semver/pub_semver.dart';

/// Generates the next release of a changelog from the Git history.
///
/// The changes are the commits since the latest release tag, or since a
/// given revision. The version is the one given by the caller or the one
/// Semantic Versioning suggests: the latest release with the bump of
/// [VersionBump], or the version of `pubspec.yaml` when it is higher or
/// when nothing has been released yet.
final class ChangelogGenerator {
  /// Creates a generator reading [history] with the settings of [config]
  /// for the package whose `pubspec.yaml` declares [packageVersion].
  const ChangelogGenerator({
    required this.history,
    required this.config,
    required this.packageVersion,
  });

  /// The Git history.
  final GitHistory history;

  /// The changelog settings.
  final ChangelogConfig config;

  /// The version in `pubspec.yaml`, or `null` when it declares none.
  final String? packageVersion;

  /// Generates the release of the commits reachable from [to] and not from
  /// [from], which defaults to the latest release tag.
  ///
  /// The version is counted from [from] when it is a release tag, and from
  /// the latest release tag otherwise.
  ///
  /// [release] is the version to release, suggested when `null`, and
  /// [date] the release date as `YYYY-MM-DD`.
  ///
  /// Returns the release; its changes are empty when there is nothing to
  /// release.
  ///
  /// Throws an [InvalidUsageException] for an invalid [release] or
  /// revision, or when no version can be suggested, and an
  /// [UnavailableException] when Git is not available.
  Future<ChangelogRelease> generate({
    required String date,
    String to = 'HEAD',
    String? from,
    String? release,
  }) async {
    final Version? requested = release == null ? null : _parse(release);
    final ReleaseTag? latest = await history.latestTag(
      to: to,
      prefix: config.tagPrefix,
    );
    final ReleaseTag? base = from == null
        ? latest
        : ReleaseTag.tryParse(from, config.tagPrefix) ?? latest;
    final List<GitCommit> commits = await history.commits(
      to: to,
      from: from ?? latest?.name,
    );
    const parser = ConventionalCommitParser();
    final parsed = <ConventionalCommit>[
      for (final commit in commits) parser.parse(commit),
    ];
    final ChangelogChanges changes = ChangelogBuilder(config).build(parsed);
    final Version version = requested ?? _suggest(base, changes.bump);
    return ChangelogRelease(
      version: '$version',
      date: date,
      changes: changes,
      tag: '${config.tagPrefix}$version',
      previousTag: from ?? latest?.name,
    );
  }

  /// Suggests the version after [previous] for a release of the size
  /// [bump].
  ///
  /// Returns the version.
  ///
  /// Throws an [InvalidUsageException] when there is neither a release tag
  /// nor a valid package version.
  Version _suggest(ReleaseTag? previous, VersionBump? bump) {
    final String? declared = packageVersion;
    final Version? package = declared == null
        ? null
        : tryParseVersion(declared);
    if (previous == null) {
      if (package == null) {
        throw const InvalidUsageException(
          'There is no release tag and pubspec.yaml declares no valid '
          'version. Pass the version to release with --release.',
        );
      }
      return package;
    }
    final Version next = (bump ?? VersionBump.patch).apply(previous.version);
    final bool packageAhead = package != null && package > next;
    return packageAhead ? package : next;
  }

  /// Parses the requested [release].
  ///
  /// Returns the version.
  ///
  /// Throws an [InvalidUsageException] when [release] is not a semantic
  /// version.
  Version _parse(String release) {
    final Version? version = tryParseVersion(release);
    if (version == null) {
      throw InvalidUsageException(
        '"$release" is not a semantic version such as 1.2.3.',
      );
    }
    return version;
  }
}
