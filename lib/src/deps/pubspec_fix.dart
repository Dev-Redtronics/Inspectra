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

/// The result of fixing one `pubspec.yaml`.
final class PubspecFix {
  /// Creates the fix that turned the file into [content] by the [applied]
  /// changes.
  const PubspecFix({required this.content, required this.applied});

  /// The fixed content of the file.
  final String content;

  /// One description per change, such as `http: >=1.2.0 -> ^1.2.0`.
  final List<String> applied;

  /// Whether anything changed.
  bool get changed => applied.isNotEmpty;
}
