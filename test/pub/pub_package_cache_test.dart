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

import 'dart:io';

import 'package:inspectra/src/pub/pub_package.dart';
import 'package:inspectra/src/pub/pub_package_cache.dart';
import 'package:inspectra/src/pub/pub_version.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/fixtures.dart';

/// Tests the disk cache of version listings.
void main() {
  final now = DateTime.utc(2026, 10);
  final package = PubPackage(
    name: 'http',
    latestVersion: '1.2.0',
    versions: <PubVersion>[
      PubVersion(version: '1.0.0', published: DateTime.utc(2024)),
      const PubVersion(version: '1.1.0', retracted: true),
      PubVersion(version: '1.2.0', published: DateTime.utc(2025)),
    ],
  );

  test('reads a fresh listing back and keeps registries apart', () {
    final cache = PubPackageCache(temporaryDirectory())
      ..write('https://pub.dev', package, now);
    final PubPackage? read = cache.read(
      'https://pub.dev',
      'http',
      now.add(const Duration(hours: 23)),
    );
    expect(read?.latestVersion, '1.2.0');
    expect(read?.versions.map((version) => version.version), <String>[
      '1.0.0',
      '1.1.0',
      '1.2.0',
    ]);
    expect(read?.find('1.0.0')?.published, DateTime.utc(2024));
    expect(read?.find('1.1.0')?.retracted, isTrue);
    expect(cache.read('https://pub.corp', 'http', now), isNull);
  });

  test('misses expired, corrupt and disabled entries', () {
    final String root = temporaryDirectory();
    final cache = PubPackageCache(root)..write('https://pub.dev', package, now);
    expect(
      cache.read('https://pub.dev', 'http', now.add(const Duration(days: 1))),
      isNull,
    );
    final File file = Directory(root)
        .listSync(recursive: true)
        .whereType<File>()
        .single;
    expect(p.basename(file.path), 'http.json');
    file.writeAsStringSync('not json');
    expect(cache.read('https://pub.dev', 'http', now), isNull);
    const disabled = PubPackageCache(null);
    disabled.write('https://pub.dev', package, now);
    expect(disabled.read('https://pub.dev', 'http', now), isNull);
  });
}
