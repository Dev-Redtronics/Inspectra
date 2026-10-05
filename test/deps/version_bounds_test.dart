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

import 'package:inspectra/src/deps/version_bounds.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

/// Tests reading and bounding version constraints.
void main() {
  test('bounds constraints without an upper bound', () {
    expect(boundedConstraint('>=1.2.0'), '^1.2.0');
    expect(boundedConstraint('>=0.13.0'), '^0.13.0');
    expect(boundedConstraint('>1.2.0'), '>1.2.0 <2.0.0');
  });

  test('leaves bounded, open and malformed constraints alone', () {
    for (final constraint in <String?>[
      '^1.2.0',
      '>=1.0.0 <2.0.0',
      '1.2.3',
      '<2.0.0',
      'any',
      '*',
      null,
      'not a constraint',
      '>=1.0.0 <2.0.0 || >=3.0.0',
    ]) {
      expect(boundedConstraint(constraint), isNull, reason: '$constraint');
    }
  });

  test('reads the lower bound', () {
    expect(lowerBound('^3.6.0'), Version(3, 6, 0));
    expect(lowerBound('>=2.19.0 <4.0.0'), Version(2, 19, 0));
    expect(lowerBound('<4.0.0'), isNull);
    expect(lowerBound(null), isNull);
    expect(parseConstraint('any'), isNull);
  });
}
