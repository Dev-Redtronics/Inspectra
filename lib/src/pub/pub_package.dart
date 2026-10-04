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

import 'pub_version.dart';

/// The version listing of a package on a pub repository.
final class PubPackage {
  /// Creates a package listing.
  const PubPackage({
    required this.name,
    required this.latestVersion,
    required this.versions,
  });

  /// The package name.
  final String name;

  /// The latest stable version.
  final String latestVersion;

  /// All published versions in repository order.
  final List<PubVersion> versions;

  /// Finds the record of [version].
  ///
  /// Returns the version record, or `null` when it was never published.
  PubVersion? find(String version) =>
      versions.where((entry) => entry.version == version).firstOrNull;

  /// The time the first version was published, which is the package's age.
  ///
  /// pub.dev does not report a creation date, so the earliest publication
  /// date of any version is used.
  DateTime? get firstPublished {
    final dates = versions.map((entry) => entry.published).nonNulls.toList()
      ..sort();
    return dates.firstOrNull;
  }
}
