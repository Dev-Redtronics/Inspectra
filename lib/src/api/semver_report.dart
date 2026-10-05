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

import 'package:inspectra/src/api/semver_result.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/command_report.dart';

/// The report of `api semver`: the API changes since the last release and
/// whether the version in `pubspec.yaml` follows them.
///
/// The JSON body has `failed`, `baseline`, `baselineVersion`, `version`,
/// `bump`, `required`, `undeclaredBreaking`, `changes` and, when the
/// comparison did not run, `skipped`.
final class SemverReport implements CommandReport {
  /// Creates the report of [result].
  const SemverReport(this.result);

  /// The outcome of the comparison.
  final SemverResult result;

  /// The name of the command.
  @override
  String get command => 'api semver';

  /// The violations of semantic versioning.
  @override
  List<Finding> get findings => result.findings;

  /// Fails on a finding at or above [threshold].
  ///
  /// Returns `true` when the command must exit with `1`.
  @override
  bool isFailing(Severity threshold) =>
      findings.any((finding) => finding.severity.isAtLeast(threshold));

  /// Builds the JSON body.
  ///
  /// Returns the JSON body.
  @override
  Map<String, Object?> toJson() => result.toJson();

  /// Writes the changes and the verdict.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    for (final String line in result.render().split('\n')) {
      final String styled = line.startsWith('  - ')
          ? style.red(line)
          : line.startsWith('  + ')
          ? style.green(line)
          : line;
      out.writeln(styled);
    }
  }
}
