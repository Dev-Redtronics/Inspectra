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

/// One breach of the repository's code rules.
final class StyleViolation {
  /// Creates a violation in [path] at one-based [line] described by
  /// [message].
  const StyleViolation(this.path, this.line, this.message);

  /// The offending file.
  final String path;

  /// The one-based line number.
  final int line;

  /// What is wrong and how to fix it.
  final String message;

  /// Returns `path:line: message`, the format editors can jump to.
  @override
  String toString() => '$path:$line: $message';
}
