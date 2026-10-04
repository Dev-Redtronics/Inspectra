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

import 'package:inspectra/src/archive/archive_entry.dart';

/// Decides whether an archive entry lies in one of the excluded top level
/// directories, such as `test/` or `example/`.
///
/// [excludedDirectories] are compared with the first path segment of
/// [entry].
///
/// Returns `true` when the entry is excluded.
bool isInExcludedDirectory(
  ArchiveEntry entry,
  List<String> excludedDirectories,
) {
  final List<String> segments = entry.path.split('/');
  return segments.length > 1 && excludedDirectories.contains(segments.first);
}
