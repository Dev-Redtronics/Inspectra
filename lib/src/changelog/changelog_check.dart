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

import 'package:inspectra/src/changelog/changelog_check_result.dart';
import 'package:inspectra/src/changelog/changelog_document.dart';
import 'package:inspectra/src/changelog/changelog_heading.dart';
import 'package:inspectra/src/changelog/changelog_problem.dart';
import 'package:inspectra/src/changelog/changelog_values.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/pub/pubspec_parser.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

/// Validates the changelog of the package in [packageRoot], the file
/// `changelog.file` of [config].
///
/// The changelog must exist; every level two heading must be a release
/// (`## 1.2.0`, `## [1.2.0] - 2026-10-04`, ...) or `Unreleased`, which
/// comes first; versions must be semantic versions, listed once and newest
/// first; dates must be `YYYY-MM-DD`; and the version of `pubspec.yaml`
/// must have a section that is not empty.
///
/// Returns the result.
///
/// Throws an [InvalidInputException] when `pubspec.yaml` is malformed.
ChangelogCheckResult checkChangelog(
  InspectraConfig config,
  String packageRoot,
) {
  final String path = config.changelog.file;
  final String? version = _packageVersion(packageRoot);
  final file = File(p.join(packageRoot, path));
  if (!file.existsSync()) {
    return ChangelogCheckResult(
      path: path,
      version: version,
      problems: const <ChangelogProblem>[
        ChangelogProblem('The changelog does not exist.'),
      ],
    );
  }
  final document = ChangelogDocument.parse(file.readAsStringSync());
  return ChangelogCheckResult(
    path: path,
    version: version,
    problems: validateChangelog(document, version: version),
  );
}

/// Validates [document], which must document [version] unless it is
/// `null`.
///
/// Returns the problems in file order.
List<ChangelogProblem> validateChangelog(
  ChangelogDocument document, {
  required String? version,
}) {
  final problems = <ChangelogProblem>[];
  final seen = <Version>{};
  Version? previous;
  for (var index = 0; index < document.headings.length; index++) {
    final ChangelogHeading heading = document.headings[index];
    if (heading.unreleased) {
      if (index > 0) {
        problems.add(
          ChangelogProblem(
            'The "Unreleased" section must come first.',
            line: heading.line,
          ),
        );
      }
      continue;
    }
    final Version? parsed = _validRelease(heading, problems);
    if (parsed == null) {
      continue;
    }
    if (!seen.add(parsed)) {
      problems.add(
        ChangelogProblem(
          'Version ${heading.version} is listed more than once.',
          line: heading.line,
        ),
      );
      continue;
    }
    final above = previous;
    if (above != null && parsed > above) {
      problems.add(
        ChangelogProblem(
          'Version ${heading.version} is listed below the lower version '
          '$above; list the newest release first.',
          line: heading.line,
        ),
      );
    }
    previous = parsed;
  }
  problems.addAll(_documents(document, version));
  return List<ChangelogProblem>.unmodifiable(problems);
}

/// Checks the version and date of the release [heading], adding what is
/// wrong to [problems].
///
/// Returns the version, or `null` when the heading is not a valid release.
Version? _validRelease(
  ChangelogHeading heading,
  List<ChangelogProblem> problems,
) {
  final String? version = heading.version;
  if (version == null) {
    problems.add(
      ChangelogProblem(
        '"## ${heading.text}" is not a release heading. Use '
        '"## 1.2.3 - YYYY-MM-DD", "## 1.2.3" or "## Unreleased".',
        line: heading.line,
      ),
    );
    return null;
  }
  final Version? parsed = tryParseVersion(version);
  if (parsed == null) {
    problems.add(
      ChangelogProblem(
        '"$version" is not a semantic version such as 1.2.3.',
        line: heading.line,
      ),
    );
    return null;
  }
  final String? date = heading.date;
  if (date != null && !isIsoDate(date)) {
    problems.add(
      ChangelogProblem(
        '"$date" is not a date in the form YYYY-MM-DD.',
        line: heading.line,
      ),
    );
  }
  return parsed;
}

/// Checks that [document] documents [version].
///
/// Returns the problems, empty when [version] is `null` or documented.
List<ChangelogProblem> _documents(ChangelogDocument document, String? version) {
  if (version == null) {
    return const <ChangelogProblem>[];
  }
  final ChangelogHeading? heading = document.find(version);
  if (heading == null) {
    return <ChangelogProblem>[
      ChangelogProblem(
        'Version $version of pubspec.yaml has no section. Add one before '
        'releasing it.',
      ),
    ];
  }
  if (document.body(heading).trim().isEmpty) {
    return <ChangelogProblem>[
      ChangelogProblem(
        'The section of version $version is empty.',
        line: heading.line,
      ),
    ];
  }
  return const <ChangelogProblem>[];
}

/// Reads the version of the package in [packageRoot].
///
/// Returns the version, or `null` when there is no `pubspec.yaml` or it
/// declares no version.
///
/// Throws an [InvalidInputException] when `pubspec.yaml` is malformed.
String? _packageVersion(String packageRoot) {
  final String path = p.join(packageRoot, 'pubspec.yaml');
  if (!File(path).existsSync()) {
    return null;
  }
  return const PubspecParser().parseFile(path).version;
}
