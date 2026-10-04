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

import '../model/source_location.dart';

/// Finds the line of a `pubspec.yaml` that declares [key].
///
/// [lines] are the lines of the file, [path] is the display path of the
/// file. The first line whose content starts with `key:` (after indentation)
/// is used, which is the declaration in every well formed pubspec.
///
/// Returns the location, with a line number when the key was found.
SourceLocation locatePubspecKey(List<String> lines, String key, String path) {
  final pattern = RegExp('^\\s*${RegExp.escape(key)}\\s*:');
  for (var index = 0; index < lines.length; index++) {
    if (pattern.hasMatch(lines[index])) {
      return SourceLocation(path, line: index + 1);
    }
  }
  return SourceLocation(path);
}
