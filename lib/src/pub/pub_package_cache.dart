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

import 'package:crypto/crypto.dart';
import 'package:inspectra/src/pub/pub_package.dart';
import 'package:inspectra/src/pub/pub_version.dart';
import 'package:path/path.dart' as p;

/// A disk cache of package version listings, so that checking how far the
/// dependencies are behind does not ask the registry for every package on
/// every run.
///
/// A listing is reused for [maxAge]; it only says which versions exist and
/// when they were published, so a day old listing is good enough.
final class PubPackageCache {
  /// Creates a cache stored in [directory] whose entries expire after
  /// [maxAge]; a `null` directory disables caching.
  const PubPackageCache(
    this.directory, {
    this.maxAge = const Duration(hours: 24),
  });

  /// The cache directory, or `null` when caching is disabled.
  final String? directory;

  /// How long a listing is reused.
  final Duration maxAge;

  /// Reads the listing of [name] from [registry] if it was cached less than
  /// [maxAge] before [now].
  ///
  /// Returns the listing, or `null` on a miss, an expired or a corrupt
  /// entry.
  PubPackage? read(String registry, String name, DateTime now) {
    final File? file = _file(registry, name);
    if (file == null || !file.existsSync()) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      final DateTime? fetched = DateTime.tryParse('${decoded['fetched']}');
      final bool fresh = fetched != null && now.difference(fetched) < maxAge;
      return fresh ? _package(name, decoded) : null;
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  /// Stores the listing [package] of [registry], fetched at [now].
  ///
  /// Write failures are ignored: the cache is an optimisation only.
  void write(String registry, PubPackage package, DateTime now) {
    final File? file = _file(registry, package.name);
    if (file == null) {
      return;
    }
    final json = <String, Object?>{
      'fetched': now.toUtc().toIso8601String(),
      'latest': package.latestVersion,
      'versions': <Map<String, Object?>>[
        for (final PubVersion version in package.versions)
          <String, Object?>{
            'version': version.version,
            'published': ?version.published?.toUtc().toIso8601String(),
            if (version.retracted) 'retracted': true,
          },
      ],
    };
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(json));
    } on FileSystemException {
      return;
    }
  }

  /// Rebuilds the listing of [name] from its cached [json].
  ///
  /// Returns the listing.
  static PubPackage _package(String name, Map<String, Object?> json) {
    final Object? versions = json['versions'];
    return PubPackage(
      name: name,
      latestVersion: '${json['latest'] ?? ''}',
      versions: <PubVersion>[
        if (versions is List<Object?>)
          for (final Object? entry in versions)
            if (entry is Map<String, Object?>)
              PubVersion(
                version: '${entry['version'] ?? ''}',
                published: DateTime.tryParse('${entry['published']}'),
                retracted: entry['retracted'] == true,
              ),
      ],
    );
  }

  /// Maps [name] of [registry] to its cache file; registries are kept apart
  /// by a hash of their URL.
  ///
  /// Returns the file, or `null` when caching is disabled.
  File? _file(String registry, String name) {
    final String? root = directory;
    if (root == null) {
      return null;
    }
    final String host = sha256
        .convert(utf8.encode(registry))
        .toString()
        .substring(0, 16);
    final String safe = name.replaceAll(RegExp('[^a-z0-9_]'), '_');
    return File(p.join(root, host, '$safe.json'));
  }
}
