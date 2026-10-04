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

/// One package of a `pubspec.lock`.
class LockedPackage {
  /// Creates a locked package.
  const LockedPackage({
    required this.name,
    required this.version,
    required this.source,
    required this.json,
  });

  /// The package name.
  final String name;

  /// The resolved version.
  final String version;

  /// Where it comes from: `hosted`, `git`, `path` or `sdk`.
  final String source;

  /// The entry as it appears in the lock file.
  final Map<String, Object?> json;

  /// Whether the package is third-party code fetched by pub, as opposed to a
  /// package of the same repository or of the SDK.
  bool get isExternal => source == 'hosted' || source == 'git';
}
