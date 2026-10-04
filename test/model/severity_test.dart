/*
 * Copyright 2026 Redtronics
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
import 'package:test/test.dart';

/// Tests the shared severity scale.
void main() {
  test('parse accepts canonical labels and aliases case-insensitively', () {
    expect(Severity.parse('critical'), Severity.critical);
    expect(Severity.parse('MODERATE'), Severity.medium);
    expect(Severity.parse('None'), Severity.low);
    expect(Severity.parse('bogus'), Severity.unknown);
    expect(Severity.parse(null), Severity.unknown);
  });

  test('tryParse rejects aliases and typos', () {
    expect(Severity.tryParse('high'), Severity.high);
    expect(Severity.tryParse('moderate'), isNull);
  });

  test('isAtLeast orders from critical to unknown', () {
    expect(Severity.high.isAtLeast(Severity.medium), isTrue);
    expect(Severity.low.isAtLeast(Severity.medium), isFalse);
    expect(Severity.unknown.isAtLeast(Severity.unknown), isTrue);
    expect(Severity.unknown.isAtLeast(Severity.low), isFalse);
  });

  test('fromCvssScore follows the CVSS qualitative scale', () {
    expect(Severity.fromCvssScore(9.8), Severity.critical);
    expect(Severity.fromCvssScore(7), Severity.high);
    expect(Severity.fromCvssScore(4), Severity.medium);
    expect(Severity.fromCvssScore(0), Severity.low);
  });
}
