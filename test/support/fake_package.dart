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

/// A resolved package as pub would leave it on disk.
class FakePackage {
  /// Creates a package [name] that depends on [dependencies].
  const FakePackage(
    this.name, {
    this.dependencies = const [],
    this.license,
    this.source = 'hosted',
  });

  /// The package name.
  final String name;

  /// The packages listed under `dependencies` in its pubspec.
  final List<String> dependencies;

  /// The content of its LICENSE file, or `null` for none.
  final String? license;

  /// Its source in the lock file.
  final String source;
}
