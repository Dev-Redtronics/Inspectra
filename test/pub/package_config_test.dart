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

import 'package:inspectra/src/pub/package_config.dart';
import 'package:inspectra/src/pub/package_location.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/fixtures.dart';

/// Tests reading `.dart_tool/package_config.json`.
void main() {
  test('resolves roots and package URIs against the file', () {
    final String root = temporaryDirectory();
    writeFile(
      root,
      'app/.dart_tool/package_config.json',
      '{"configVersion": 2, "packages": [ '
          '{"name": "acme", "rootUri": "../../acme", "packageUri": "src/"}, '
          '{"name": "app", "rootUri": "../"}, '
          '{"name": 7}, '
          '"broken"]}',
    );
    final Map<String, PackageLocation> packages = readPackageConfig(
      File(p.join(root, 'app', '.dart_tool', 'package_config.json')),
    );
    expect(packages.keys, <String>['acme', 'app']);
    expect(packages['acme']?.root, p.join(root, 'acme'));
    expect(
      packages['acme']?.resolve('inspectra.yaml'),
      p.join(root, 'acme', 'src', 'inspectra.yaml'),
    );
    expect(packages['app']?.packageUri, 'lib/');
  });

  test('reads nothing from a file without packages', () {
    final String root = temporaryDirectory();
    writeFile(root, 'package_config.json', '{"configVersion": 2}');
    expect(
      readPackageConfig(File(p.join(root, 'package_config.json'))),
      isEmpty,
    );
  });
}
