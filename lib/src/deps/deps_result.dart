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
  /// after the [fixes] were applied.
  const DepsResult({
    required this.pubspecs,
    required this.findings,
    this.fixes = const <String>[],
  });

  /// The checked pubspecs, relative to the working directory.
  final List<String> pubspecs;

  /// The findings of the pubspec rules and the dependency policy.
  final List<Finding> findings;

  /// One description per applied fix, prefixed with its pubspec.
  final List<String> fixes;
}
