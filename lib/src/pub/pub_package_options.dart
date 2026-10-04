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

/// The publisher controlled status flags of a package.
final class PubPackageOptions {
  /// Creates an options record.
  const PubPackageOptions({
    this.isDiscontinued = false,
    this.isUnlisted = false,
    this.replacedBy,
  });

  /// Whether the publisher discontinued the package.
  final bool isDiscontinued;

  /// Whether the package is hidden from search results.
  final bool isUnlisted;

  /// The package recommended as replacement, if any.
  final String? replacedBy;
}
