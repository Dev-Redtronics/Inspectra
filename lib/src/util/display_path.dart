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

import 'package:path/path.dart' as p;

/// Renders [path] relative to [from] with forward slashes.
///
/// Reports use this form so that they are identical on Windows and POSIX
/// hosts and so that SARIF consumers can map findings to repository files.
/// Paths outside of [from] keep their absolute form.
///
/// Returns the display path; `.` for [from] itself.
String displayPath(String path, String from) {
  final absolute = p.normalize(p.absolute(path));
  final base = p.normalize(p.absolute(from));
  final isInside = absolute == base || p.isWithin(base, absolute);
  if (!isInside) {
    return absolute.replaceAll(r'\', '/');
  }
  return p.split(p.relative(absolute, from: base)).join('/');
}
