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

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Builds a `.tar.gz` archive containing [files], keyed by entry name.
///
/// Returns the compressed bytes.
Uint8List buildTarGz(Map<String, String> files) {
  final archive = Archive();
  for (final MapEntry<String, String> entry in files.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, utf8.encode(entry.value)));
  }
  final Uint8List tar = TarEncoder().encodeBytes(archive);
  return Uint8List.fromList(const GZipEncoder().encodeBytes(tar));
}

/// Builds a `.tar.gz` archive with binary [files], keyed by entry name.
///
/// Returns the compressed bytes.
Uint8List buildBinaryTarGz(Map<String, List<int>> files) {
  final archive = Archive();
  for (final MapEntry<String, List<int>> entry in files.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  final Uint8List tar = TarEncoder().encodeBytes(archive);
  return Uint8List.fromList(const GZipEncoder().encodeBytes(tar));
}

/// Builds a `.zip` archive containing [files], keyed by entry name.
///
/// Returns the archive bytes.
Uint8List buildZip(Map<String, List<int>> files) {
  final archive = Archive();
  for (final MapEntry<String, List<int>> entry in files.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}
