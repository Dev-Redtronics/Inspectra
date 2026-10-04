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

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/pub/package_name.dart';
import 'package:test/test.dart';

/// Tests package name and version validation.
void main() {
  test('accepts valid names and rejects path or URL injection', () {
    expect(PackageName.validate('http_parser'), 'http_parser');
    for (final name in <String>['../etc', 'a/b', '1abc', 'a b', '']) {
      expect(
        () => PackageName.validate(name),
        throwsA(isA<InvalidUsageException>()),
      );
    }
  });

  test('accepts exact versions only', () {
    expect(PackageName.validateExactVersion('1.2.3-dev.1'), '1.2.3-dev.1');
    expect(
      () => PackageName.validateExactVersion('^1.2.0'),
      throwsA(isA<InvalidUsageException>()),
    );
  });
}
