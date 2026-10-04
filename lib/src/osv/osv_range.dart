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

/// One `ranges[]` entry of an affected package in an OSV record.
final class OsvRange {
  /// Creates a range of the given [type] with its ordered [events].
  const OsvRange({required this.type, required this.events});

  /// The range type: `SEMVER`, `ECOSYSTEM` or `GIT`.
  final String type;

  /// The ordered events; each map has exactly one key such as
  /// `introduced`, `fixed`, `last_affected` or `limit`.
  final List<Map<String, String>> events;
}
