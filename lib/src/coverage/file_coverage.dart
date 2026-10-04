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

/// The line coverage of one source file.
class FileCoverage {
  /// Creates the coverage of [path].
  const FileCoverage(this.path, this.linesFound, this.linesHit);

  /// The file, relative to the package root.
  final String path;

  /// The number of executable lines.
  final int linesFound;

  /// The number of executable lines that ran.
  final int linesHit;

  /// The covered share of lines in percent; 100 for a file without lines.
  double get percent => linesFound == 0 ? 100 : linesHit * 100 / linesFound;
}
