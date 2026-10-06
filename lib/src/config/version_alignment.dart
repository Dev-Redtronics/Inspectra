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

/// How alike the constraints of one external dependency must be across
/// the packages of a workspace, `workspace_policy.align_versions`.
enum VersionAlignment {
  /// Any constraints; the rule is off.
  off('off'),

  /// The constraints must allow at least one common version, which pub
  /// needs to resolve the workspace at all.
  compatible('compatible'),

  /// Every package writes the same constraint.
  exact('exact');

  /// Creates the alignment spelled [id] in the configuration.
  const VersionAlignment(this.id);

  /// The spelling in the configuration.
  final String id;
}
