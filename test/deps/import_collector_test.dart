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

import 'package:inspectra/src/deps/import_collector.dart';
import 'package:inspectra/src/deps/package_imports.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

/// Tests collecting the packages a package imports.
void main() {
  test('reads imports, exports and conditional imports', () {
    expect(
      ImportCollector.packagesOf('''
library;

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:stub/stub.dart'
    if (dart.library.io) 'package:io_impl/io.dart'
    if (dart.library.js_interop) 'package:web_impl/web.dart';
export 'package:path/path.dart' show join;
import 'src/local.dart';
part 'part.dart';
''', 'lib/a.dart'),
      <String>{'http', 'stub', 'io_impl', 'web_impl', 'path'},
    );
  });

  test('tolerates files that do not parse', () {
    expect(
      ImportCollector.packagesOf(
        "import 'package:http/http.dart';\nclass {",
        'lib/broken.dart',
      ),
      <String>{'http'},
    );
  });

  test('separates runtime and development code, without nested packages', () {
    final String root = temporaryDirectory();
    writeFile(root, 'lib/a.dart', "import 'package:http/http.dart';\n");
    writeFile(root, 'bin/main.dart', "import 'package:args/args.dart';\n");
    writeFile(root, 'test/a_test.dart', "import 'package:test/test.dart';\n");
    writeFile(root, 'tool/gen.dart', "import 'package:yaml/yaml.dart';\n");
    writeFile(root, 'example/pubspec.yaml', 'name: example\n');
    writeFile(
      root,
      'example/lib/main.dart',
      "import 'package:flutter/material.dart';\n",
    );
    writeFile(root, 'lib/.dart_tool/x.dart', "import 'package:x/x.dart';\n");
    final PackageImports imports = const ImportCollector().collect(root);
    expect(imports.runtime, <String>{'http', 'args'});
    expect(imports.development, <String>{'test', 'yaml'});
  });
}
