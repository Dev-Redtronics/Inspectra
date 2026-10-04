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

import 'package:inspectra/src/changelog/changelog_problem.dart';

/// The outcome of validating a changelog.
final class ChangelogCheckResult {
  /// Creates the outcome for the changelog at [path], relative to the
  /// package root, which must document [version], the version of
  /// `pubspec.yaml` (`null` when the package has none).
  const ChangelogCheckResult({
    required this.path,
    required this.version,
    required this.problems,
  });

  /// The changelog, relative to the package root.
  final String path;

  /// The version that must be documented, or `null` when the package has
  /// no version.
  final String? version;

  /// Every problem found, in file order.
  final List<ChangelogProblem> problems;

  /// Whether the check failed.
  bool get failed => problems.isNotEmpty;

  /// A readable summary for the console.
  ///
  /// Returns the summary.
  String render() {
    final String? documented = version;
    if (!failed) {
      return documented == null
          ? '$path is well-formed.'
          : '$path is well-formed and documents version $documented.';
    }
    final out = StringBuffer('$path has ${problems.length} problem(s):\n');
    for (final ChangelogProblem problem in problems) {
      final int? line = problem.line;
      final String location = line == null ? path : '$path:$line';
      out.write('\n  $location: ${problem.message}');
    }
    out.write(
      '\n\nGenerate the section of the next release from the Git history '
      'with:\n\n    dart run inspectra changelog generate --write',
    );
    return out.toString();
  }
}
