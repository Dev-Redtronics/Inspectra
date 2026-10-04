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

import 'dart:convert';
import 'dart:typed_data';

import 'package:inspectra/src/archive/archive_entry.dart';
import 'package:inspectra/src/archive/archive_entry_kind.dart';

/// Creates an in-memory regular file entry at [path] with text [content].
///
/// Returns the entry.
ArchiveEntry textEntry(String path, String content, {int mode = 0x1A4}) {
  return ArchiveEntry(
    name: path,
    kind: ArchiveEntryKind.file,
    mode: mode,
    bytes: Uint8List.fromList(utf8.encode(content)),
  );
}

/// Creates an in-memory entry of [kind] at [path] with raw [bytes].
///
/// Returns the entry.
ArchiveEntry rawEntry(
  String path,
  ArchiveEntryKind kind, {
  List<int> bytes = const <int>[],
  String? linkTarget,
  int mode = 0x1A4,
}) {
  return ArchiveEntry(
    name: path,
    kind: kind,
    mode: mode,
    linkTarget: linkTarget,
    bytes: Uint8List.fromList(bytes),
  );
}
