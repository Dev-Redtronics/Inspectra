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

import 'package:inspectra/src/model/finding.dart';

/// The outcome of checking the pubspecs of a project with `deps`.
final class DepsResult {
  /// Creates the result of checking [pubspecs], which found [findings]
  /// after the [fixes] were applied; [outdatedChecked] tells whether the
  /// rules that need the registry ran, `null` when none is configured, and
  /// [libyears] what the dependencies add up to when they did.
  const DepsResult({
    required this.pubspecs,
    required this.findings,
    this.fixes = const <String>[],
    this.outdatedChecked,
    this.libyears,
  });

  /// The checked pubspecs, relative to the working directory.
  final List<String> pubspecs;

  /// The findings of the pubspec rules and the dependency policy.
  final List<Finding> findings;

  /// One description per applied fix, prefixed with its pubspec.
  final List<String> fixes;

  /// Whether `max_major_behind` and `max_libyear` were checked against the
  /// registry, or `null` when neither is configured.
  final bool? outdatedChecked;

  /// The libyears of the dependencies, added up over every checked
  /// package, or `null` when they were not computed.
  final double? libyears;

  /// Copies this result with the [extra] findings added, such as those of
  /// the workspace policy.
  ///
  /// Returns the copy.
  DepsResult withFindings(List<Finding> extra) => DepsResult(
    pubspecs: pubspecs,
    findings: <Finding>[...findings, ...extra],
    fixes: fixes,
    outdatedChecked: outdatedChecked,
    libyears: libyears,
  );
}
