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

import 'package:inspectra/src/osv/fixed_version_resolver.dart';
import 'package:inspectra/src/osv/osv_affected.dart';
import 'package:inspectra/src/osv/osv_range.dart';
import 'package:test/test.dart';

/// Tests the selection of the fix that applies to the installed version.
void main() {
  const resolver = FixedVersionResolver();

  /// Creates an affected entry for `pkg` with one range per event list.
  List<OsvAffected> affected(List<List<Map<String, String>>> ranges) =>
      <OsvAffected>[
        OsvAffected(
          packageName: 'pkg',
          ecosystem: 'Pub',
          ranges: <OsvRange>[
            for (final events in ranges)
              OsvRange(type: 'ECOSYSTEM', events: events),
          ],
        ),
      ];

  final twoLines = affected(<List<Map<String, String>>>[
    <Map<String, String>>[
      <String, String>{'introduced': '0'},
      <String, String>{'fixed': '1.5.0'},
    ],
    <Map<String, String>>[
      <String, String>{'introduced': '2.0.0'},
      <String, String>{'fixed': '2.3.1'},
    ],
  ]);

  test('returns the fix of the range containing the installed version', () {
    expect(resolver.resolve(twoLines, 'pkg', '1.2.0'), '1.5.0');
    expect(resolver.resolve(twoLines, 'pkg', '2.1.0'), '2.3.1');
  });

  test('falls back to the smallest fix above the installed version', () {
    expect(resolver.resolve(twoLines, 'pkg', '1.7.0'), '2.3.1');
  });

  test('returns null for last_affected ranges and other packages', () {
    final noFix = affected(<List<Map<String, String>>>[
      <Map<String, String>>[
        <String, String>{'introduced': '0'},
        <String, String>{'last_affected': '3.0.0'},
      ],
    ]);
    expect(resolver.resolve(noFix, 'pkg', '2.0.0'), isNull);
    expect(resolver.resolve(twoLines, 'other', '1.0.0'), isNull);
  });
}
