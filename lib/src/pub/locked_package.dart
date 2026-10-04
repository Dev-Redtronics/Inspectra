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

/// One package entry of a `pubspec.lock` file.
final class LockedPackage {
  /// Creates a locked package.
  ///
  /// [source] is the pub source (`hosted`, `git`, `path` or `sdk`),
  /// [dependency] the lockfile's dependency kind such as `direct main` or
  /// `transitive`, and [hostedUrl] the registry of hosted packages.
  const LockedPackage({
    required this.name,
    required this.version,
    required this.source,
    required this.dependency,
    this.hostedUrl,
  });

  /// The package name.
  final String name;

  /// The resolved version.
  final String version;

  /// The pub source the package was resolved from.
  final String source;

  /// The dependency kind, for example `direct main`, `direct dev`,
  /// `direct overridden` or `transitive`.
  final String dependency;

  /// The registry URL of a hosted package, or `null` for other sources.
  final String? hostedUrl;

  /// Whether the package is a direct dependency of the project.
  bool get isDirect => dependency.startsWith('direct');

  /// Whether the package was resolved from a package registry.
  bool get isHosted => source == 'hosted';

  /// Returns `name version (source)`.
  @override
  String toString() => '$name $version ($source)';
}
