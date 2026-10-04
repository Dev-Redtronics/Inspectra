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

import 'package:inspectra/src/osv/cvss_v2_calculator.dart';
import 'package:inspectra/src/osv/cvss_v3_calculator.dart';
import 'package:test/test.dart';

/// Tests the CVSS base score calculators against published reference
/// scores.
void main() {
  group('CVSS v3', () {
    const calculator = CvssV3Calculator();
    final references = <String, double>{
      'CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H': 9.8,
      'CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N': 6.1,
      'CVSS:3.1/AV:N/AC:H/PR:N/UI:N/S:U/C:H/I:N/A:N': 5.9,
      'CVSS:3.0/AV:N/AC:L/PR:L/UI:N/S:C/C:H/I:H/A:H': 9.9,
      'CVSS:3.1/AV:L/AC:L/PR:L/UI:N/S:U/C:H/I:N/A:N': 5.5,
      'CVSS:3.1/AV:P/AC:H/PR:H/UI:R/S:U/C:N/I:N/A:N': 0,
    };
    for (final MapEntry<String, double> entry in references.entries) {
      test(entry.key, () {
        expect(calculator.baseScore(entry.key), entry.value);
      });
    }

    test('rejects incomplete vectors', () {
      expect(calculator.baseScore('CVSS:3.1/AV:N'), isNull);
      expect(calculator.baseScore('AV:N/AC:L/Au:N/C:P/I:P/A:P'), isNull);
    });

    test('roundUp follows the CVSS v3.1 specification', () {
      expect(CvssV3Calculator.roundUp(4.02), 4.1);
      expect(CvssV3Calculator.roundUp(4), 4.0);
      expect(CvssV3Calculator.roundUp(4.000002), 4.0);
    });
  });

  group('CVSS v2', () {
    const calculator = CvssV2Calculator();

    test('computes reference scores', () {
      expect(calculator.baseScore('AV:N/AC:L/Au:N/C:P/I:P/A:P'), 7.5);
      expect(calculator.baseScore('AV:N/AC:M/Au:N/C:N/I:P/A:N'), 4.3);
      expect(calculator.baseScore('AV:N/AC:L/Au:N/C:C/I:C/A:C'), 10.0);
    });

    test('rejects incomplete vectors', () {
      expect(calculator.baseScore('AV:N/AC:L'), isNull);
    });
  });
}
