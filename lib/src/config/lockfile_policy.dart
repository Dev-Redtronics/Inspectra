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

/// Whether a package must commit its `pubspec.lock`,
/// `dependency_policy.lockfile_policy`.
enum LockfilePolicy {
  /// Either way; the rule is off.
  any('any'),

  /// The lockfile must be committed, as for applications.
  committed('committed'),

  /// The lockfile must not be committed, as for published libraries.
  ignored('ignored'),

  /// Applications commit the lockfile, packages that can be published do
  /// not.
  auto('auto');

  /// Creates the policy spelled [id] in the configuration.
  const LockfilePolicy(this.id);

  /// The spelling in the configuration.
  final String id;
}
