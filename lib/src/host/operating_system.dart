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

/// The operating system family Inspectra is running on.
enum OperatingSystem {
  /// Any Linux distribution.
  linux('linux'),

  /// Apple macOS.
  macos('macos'),

  /// Microsoft Windows.
  windows('windows'),

  /// Any other system, for example Android or Fuchsia.
  other('other');

  /// Creates an operating system with the identifier used by the Dart
  /// `Abi` naming scheme, for example `macos` in `macos_arm64`.
  const OperatingSystem(this.abiName);

  /// The identifier used by the Dart `Abi` naming scheme.
  final String abiName;

  /// Finds the operating system whose [abiName] equals [name].
  ///
  /// Returns the matching system, or [other] when none matches.
  static OperatingSystem fromAbiName(String name) {
    final Iterable<OperatingSystem> matches = values.where(
      (system) => system.abiName == name,
    );
    return matches.firstOrNull ?? OperatingSystem.other;
  }
}
