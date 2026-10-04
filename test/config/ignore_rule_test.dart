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
import 'package:test/test.dart';

/// Tests ignore rule matching and expiry.
void main() {
  const finding = Finding(
    ruleId: 'GHSA-1',
    source: FindingSource.osv,
    severity: Severity.high,
    title: 't',
    packageName: 'http',
    aliases: <String>['CVE-1'],
  );

  test('matches by rule id or alias, optionally scoped to a package', () {
    expect(const IgnoreRule(id: 'CVE-1', reason: 'r').matches(finding), isTrue);
    const scoped = IgnoreRule(id: 'GHSA-1', reason: 'r', package: 'dio');
    expect(scoped.matches(finding), isFalse);
  });

  test('is valid through the whole expiry day', () {
    final rule = IgnoreRule(id: 'x', reason: 'r', expires: DateTime(2026, 5));
    expect(rule.isExpired(DateTime.utc(2026, 5, 1, 23, 59)), isFalse);
    expect(rule.isExpired(DateTime.utc(2026, 5, 2)), isTrue);
  });
}
