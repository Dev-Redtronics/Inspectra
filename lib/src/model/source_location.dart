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

/// A position inside a file that a finding refers to.
///
/// Paths are always stored with forward slashes and relative to the scanned
/// root, so that reports are identical on Windows and POSIX hosts and stable
/// fingerprints can be computed from them.
final class SourceLocation {
  /// Creates a location pointing at [path], optionally narrowed down to a
  /// one-based [line].
  const SourceLocation(this.path, {this.line});

  /// The file path relative to the scanned root, using `/` as separator.
  final String path;

  /// The one-based line number, or `null` when the finding concerns the file
  /// as a whole.
  final int? line;

  /// Renders the location as `path` or `path:line`.
  ///
  /// Returns the human readable location.
  @override
  String toString() {
    final int? currentLine = line;
    if (currentLine == null) {
      return path;
    }
    return '$path:$currentLine';
  }
}
