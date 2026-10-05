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
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// The downloaded remote bases of configurations, one file per SHA-256 in
/// the `config` directory of the Inspectra cache.
///
/// A file is used only while its content still has the SHA-256 it is
/// named after, so a damaged or altered cache is downloaded again.
final class ConfigBaseCache {
  /// Creates the cache below [cacheRoot].
  const ConfigBaseCache(this.cacheRoot);

  /// The Inspectra cache directory.
  final String cacheRoot;

  /// Returns the file of the base with the SHA-256 [sha256].
  String fileOf(String sha256) => p.join(cacheRoot, 'config', '$sha256.yaml');

  /// Reads the base with the SHA-256 [sha256].
  ///
  /// Returns its text, or `null` when it is not cached or its content does
  /// not match.
  String? read(String sha256) {
    final file = File(fileOf(sha256));
    try {
      if (!file.existsSync()) {
        return null;
      }
      final List<int> bytes = file.readAsBytesSync();
      final matches = digestOf(bytes) == sha256;
      return matches ? utf8.decode(bytes, allowMalformed: true) : null;
    } on FileSystemException {
      return null;
    }
  }

  /// Stores [bytes] as the base with the SHA-256 [sha256], replacing the
  /// cached file at once so that no reader sees a partial file.
  ///
  /// Throws a [FileSystemException] when the cache cannot be written.
  void write(String sha256, List<int> bytes) {
    final target = File(fileOf(sha256));
    final Directory directory = target.parent..createSync(recursive: true);
    final String suffix = Random.secure().nextInt(1 << 32).toRadixString(16);
    final temporary = File(p.join(directory.path, '.$sha256-$suffix.tmp'));
    try {
      temporary
        ..writeAsBytesSync(bytes, flush: true)
        ..renameSync(target.path);
    } finally {
      if (temporary.existsSync()) {
        temporary.deleteSync();
      }
    }
  }

  /// Returns the lower case hexadecimal SHA-256 of [bytes].
  static String digestOf(List<int> bytes) => sha256.convert(bytes).toString();
}
