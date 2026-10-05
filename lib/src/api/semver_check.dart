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

import 'package:inspectra/src/api/api_change.dart';
import 'package:inspectra/src/api/api_change_kind.dart';
import 'package:inspectra/src/api/api_changes.dart';
import 'package:inspectra/src/api/api_command.dart';
import 'package:inspectra/src/api/api_surface.dart';
import 'package:inspectra/src/api/semver_result.dart';
import 'package:inspectra/src/changelog/changelog_values.dart';
import 'package:inspectra/src/changelog/conventional_commit.dart';
import 'package:inspectra/src/changelog/conventional_commit_parser.dart';
import 'package:inspectra/src/changelog/git_commit.dart';
import 'package:inspectra/src/changelog/git_history.dart';
import 'package:inspectra/src/changelog/release_tag.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/pub/pubspec_parser.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

/// Compares the public API of the package in [packageRoot] with the API
/// dump committed at the last release tag, or at the revision [from], read
/// through [history], and checks the version in `pubspec.yaml`.
///
/// The release tag is the highest tag with the prefix
/// `changelog.tag_prefix` reachable from `HEAD`. With `changelog.enabled`,
/// a breaking change also needs a commit marked as breaking since then.
///
/// Returns the result; it is skipped without a release, without a dump at
/// the release, or without a version in `pubspec.yaml`.
///
/// Throws an `InvalidUsageException` outside of a Git repository or for an
/// unknown revision, an `UnavailableException` when Git is missing, and an
/// `InvalidInputException` when the package cannot be analysed.
Future<SemverResult> checkSemver(
  InspectraConfig config,
  String packageRoot,
  GitHistory history, {
  String? from,
}) async {
  final String dumpPath = config.api.output;
  final String? declared = const PubspecParser()
      .parseFile(p.join(packageRoot, 'pubspec.yaml'))
      .version;
  final Version? version = declared == null ? null : tryParseVersion(declared);
  if (version == null) {
    return SemverResult.skipped(
      'pubspec.yaml declares no version to check.',
      dumpPath: dumpPath,
    );
  }
  final String prefix = config.changelog.tagPrefix;
  final revision = from;
  final ReleaseTag? tag = revision == null && await history.hasCommits()
      ? await history.latestTag(to: 'HEAD', prefix: prefix)
      : null;
  final String? baseline = revision ?? tag?.name;
  if (baseline == null) {
    return SemverResult.skipped(
      'no release tag with the prefix "$prefix" yet, so there is no earlier '
      'API to compare with.',
      dumpPath: dumpPath,
    );
  }
  final String? before = await history.show(baseline, dumpPath);
  if (before == null) {
    return SemverResult.skipped(
      '$baseline has no API dump at $dumpPath; record it with "api dump" '
      'and commit it before tagging a release.',
      dumpPath: dumpPath,
    );
  }
  final String after = await renderPackageApi(config, packageRoot);
  final List<GitCommit> commits = config.changelog.enabled
      ? await history.commits(from: baseline, to: 'HEAD')
      : const <GitCommit>[];
  return evaluateSemver(
    before: before,
    after: after,
    baseline: baseline,
    baselineVersion:
        tag?.version ??
        ReleaseTag.tryParse(baseline, prefix)?.version ??
        tryParseVersion(baseline),
    version: version,
    commits: config.changelog.enabled
        ? <ConventionalCommit>[
            for (final GitCommit commit in commits)
              const ConventionalCommitParser().parse(commit),
          ]
        : null,
    dumpPath: dumpPath,
  );
}

/// Compares the API dump [before], recorded at [baseline] of version
/// [baselineVersion], with the dump [after] and the declared [version];
/// [commits] are the commits since [baseline] when the changelog is
/// checked as well.
///
/// Returns the result.
SemverResult evaluateSemver({
  required String before,
  required String after,
  required String baseline,
  required Version? baselineVersion,
  required Version version,
  List<ConventionalCommit>? commits,
  String dumpPath = '',
}) {
  final List<ApiChange> changes = classifyApiChanges(
    ApiSurface.parse(before),
    ApiSurface.parse(after),
  );
  final bool breaks = changes.any(
    (change) => change.kind == ApiChangeKind.breaking,
  );
  final bool announced =
      commits == null || commits.any((commit) => commit.breaking);
  return SemverResult(
    baseline: baseline,
    baselineVersion: baselineVersion,
    version: version,
    changes: changes,
    undeclaredBreaking: breaks && !announced,
    dumpPath: dumpPath,
  );
}
