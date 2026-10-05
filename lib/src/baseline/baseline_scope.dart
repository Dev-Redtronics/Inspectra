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

/// The part of Inspectra whose findings a baseline entry belongs to.
///
/// Each scope is recorded and pruned on its own, so that
/// `inspectra baseline create --only style` leaves the entries of the other
/// scopes untouched.
enum BaselineScope {
  /// The findings of `scan`, which `audit`, `typosquat` and `trivy` without
  /// scan names report a part of.
  scan('scan'),

  /// The diagnostics of `dart analyze`, reported by the lint check.
  lint('lint'),

  /// The violations of the style check.
  style('style'),

  /// The findings of the configured Trivy scans; the source of an entry is
  /// the name of the scan.
  trivy('trivy');

  /// Creates a scope with its stable [id].
  const BaselineScope(this.id);

  /// The name of the scope in the baseline file and on the command line.
  final String id;

  /// Looks up the scope named [id].
  ///
  /// Returns the scope, or `null` when [id] names none.
  static BaselineScope? tryParse(String id) =>
      values.where((scope) => scope.id == id).firstOrNull;
}
