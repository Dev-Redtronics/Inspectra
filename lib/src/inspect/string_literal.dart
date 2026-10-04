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

/// The content of one Dart string literal and the line it starts on.
final class StringLiteral {
  /// Creates a literal with its [value] starting on one-based [line].
  const StringLiteral(this.value, this.line);

  /// The literal text without quotes; interpolations split a literal into
  /// several values.
  final String value;

  /// The one-based line on which the literal starts.
  final int line;
}
