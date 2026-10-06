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

import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/pub/pubspec_locator.dart';

/// One package of a pub workspace, the root included.
final class WorkspaceMember {
  /// Creates the member in [directory], shown as [path] relative to the
  /// workspace root, whose `pubspec.yaml` at [pubspecPath] parsed to
  /// [pubspec] and is located by [locator].
  const WorkspaceMember({
    required this.directory,
    required this.path,
    required this.pubspecPath,
    required this.pubspec,
    required this.locator,
  });

  /// The absolute directory of the package.
  final String directory;

  /// The directory relative to the workspace root with `/` separators,
  /// `.` for the root.
  final String path;

  /// The absolute path of its `pubspec.yaml`.
  final String pubspecPath;

  /// The parsed pubspec.
  final Pubspec pubspec;

  /// Finds the lines of the pubspec, for findings.
  final PubspecLocator locator;

  /// The package name, or the [path] when the pubspec has none.
  String get name => pubspec.name ?? path;

  /// Whether this is the workspace root.
  bool get isRoot => path == '.';
}
