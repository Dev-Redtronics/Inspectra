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

/// How the hosted dependencies of a pubspec write their version
/// constraints, `dependency_policy.constraint_style`.
enum ConstraintStyle {
  /// Any constraint; the rule is off.
  any('any'),

  /// A caret constraint such as `^1.2.0`.
  caret('caret'),

  /// An explicit range such as `>=1.2.0 <2.0.0`.
  range('range'),

  /// An exact version such as `1.2.3`, for applications that pin every
  /// dependency.
  pinned('pinned');

  /// Creates the style spelled [id] in the configuration.
  const ConstraintStyle(this.id);

  /// The spelling in the configuration.
  final String id;
}
