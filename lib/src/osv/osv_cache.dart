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
import 'dart:io';

import 'package:inspectra/src/osv/osv_vulnerability.dart';
import 'package:path/path.dart' as p;

/// A disk cache of full OSV records.
///
/// `querybatch` only returns each advisory's id and modification time. The
/// full record is fetched once and cached; it is reused for as long as the
/// modification time reported by `querybatch` is unchanged, which makes
/// repeated CI runs fast and gentle on OSV.dev.
final class OsvCache {
  /// Creates a cache stored in [directory]; a `null` directory disables
  /// caching.
  const OsvCache(this.directory);

  /// The cache directory, or `null` when caching is disabled.
  final String? directory;

  /// Reads the record of [id] if it was cached with modification time
  /// [modified].
  ///
  /// Returns the cached record, or `null` on a miss or a corrupt entry.
  OsvVulnerability? read(String id, String modified) {
    final File? file = _file(id);
    if (file == null || !file.existsSync()) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      final record = OsvVulnerability.fromJson(decoded);
      return record.modified == modified ? record : null;
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  /// Stores the raw [json] record of [id].
  ///
  /// Write failures are ignored: the cache is an optimisation only.
  void write(String id, Map<String, Object?> json) {
    final File? file = _file(id);
    if (file == null) {
      return;
    }
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(json));
    } on FileSystemException {
      return;
    }
  }

  /// Maps [id] to its cache file, replacing characters that are not safe
  /// in file names.
  ///
  /// Returns the file, or `null` when caching is disabled.
  File? _file(String id) {
    final String? root = directory;
    if (root == null) {
      return null;
    }
    final String safeName = id.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
    return File(p.join(root, '$safeName.json'));
  }
}
