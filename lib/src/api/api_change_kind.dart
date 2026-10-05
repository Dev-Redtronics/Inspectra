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

/// Whether a change of the public API breaks its consumers.
enum ApiChangeKind {
  /// Consumers may no longer compile: a major version, or a minor version
  /// before 1.0.0.
  breaking('breaking'),

  /// Consumers still compile and can use something new: a minor version,
  /// or a patch version before 1.0.0.
  additive('additive');

  /// Creates the kind spelled [id] in reports.
  const ApiChangeKind(this.id);

  /// The spelling in the JSON report.
  final String id;
}
