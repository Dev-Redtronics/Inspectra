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

import 'package:inspectra/src/api/diff_kind.dart';

/// One line of the aligned comparison behind an API diff.
final class DiffLine {
  /// Creates a line of [kind] with its [text] and its line numbers [before]
  /// and [after] in the expected and the actual text.
  const DiffLine(this.kind, this.text, this.before, this.after);

  /// How the line relates the two texts.
  final DiffKind kind;

  /// The content of the line.
  final String text;

  /// The 1-based line number in the expected text, for unchanged and removed
  /// lines; for an added line, the number of the line it follows.
  final int before;

  /// The 1-based line number in the actual text, for unchanged and added
  /// lines; for a removed line, the number of the line it follows.
  final int after;
}
