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

import 'package:inspectra/src/pub/package_location.dart';
import 'package:path/path.dart' as p;

/// Reads the `.dart_tool/package_config.json` [file] that `dart pub get`
/// writes.
///
/// Returns the location of every package keyed by name; entries without a
/// name or root are skipped.
///
/// Throws a [FormatException] when the file is no JSON and a
/// [FileSystemException] when it cannot be read.
Map<String, PackageLocation> readPackageConfig(File file) {
  final Object? json = jsonDecode(file.readAsStringSync());
  final Object? packages = json is Map ? json['packages'] : null;
  final result = <String, PackageLocation>{};
  if (packages is! List) {
    return result;
  }
  final Uri base = file.absolute.uri;
  for (final Object? package in packages) {
    if (package is! Map) {
      continue;
    }
    final Object? name = package['name'];
    final Object? rootUri = package['rootUri'];
    final Object? packageUri = package['packageUri'];
    if (name is! String || rootUri is! String) {
      continue;
    }
    final Uri uri = base.resolve(rootUri.endsWith('/') ? rootUri : '$rootUri/');
    result[name] = PackageLocation(
      root: p.normalize(uri.toFilePath()),
      packageUri: packageUri is String ? packageUri : 'lib/',
    );
  }
  return result;
}
