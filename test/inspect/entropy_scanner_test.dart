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
import 'package:inspectra/src/inspect/entropy_scanner.dart';
import 'package:test/test.dart';

import '../support/entries.dart';

/// Tests the entropy scanner.
void main() {
  const scanner = EntropyScanner(excludedSuffixes: <String>['.g.dart']);

  test('computes Shannon entropy over code points', () {
    expect(EntropyScanner.shannonEntropy(''), 0);
    expect(EntropyScanner.shannonEntropy('aaaa'), 0);
    expect(EntropyScanner.shannonEntropy('ab'), closeTo(1, 1e-9));
  });

  test('flags long random looking literals', () {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final secret = String.fromCharCodes(<int>[
      for (var i = 0; i < 60; i++) alphabet.codeUnitAt((i * 7) % 62),
    ]);
    final findings = scanner.scan([
      textEntry('lib/k.dart', "const k = '$secret';"),
    ]);
    expect(findings.single.severity, Severity.high);
    expect(findings.single.attributes['entropy'], greaterThan(5.5));
  });

  test('ignores prose, character tables, generated and short strings', () {
    final findings = scanner.scan([
      textEntry(
        'lib/a.dart',
        "const a = 'application/x-www-form-urlencoded; c=1';",
      ),
      textEntry(
        'lib/b.dart',
        "const b = 'abcdefghijklmnopqrstuvwxyz0123456789';",
      ),
      textEntry(
        'lib/c.g.dart',
        "const c = 'Zq8xP3vL0mN7wR2tY5uB9cK4jH6gF1dS0aE3iO7pQ';",
      ),
      textEntry('lib/d.dart', "const d = 'Zq8xP3vL0m';"),
    ]);
    expect(findings, isEmpty);
  });
}
