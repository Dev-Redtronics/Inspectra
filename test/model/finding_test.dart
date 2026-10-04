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

/// Tests the normalised finding model.
void main() {
  const finding = Finding(
    ruleId: 'GHSA-1',
    source: FindingSource.osv,
    severity: Severity.high,
    title: 'Summary',
    packageName: 'http',
    packageVersion: '0.13.0',
    aliases: <String>['CVE-2020-1'],
    location: SourceLocation('pubspec.lock'),
  );

  test('identifiers contain the rule id and every alias', () {
    expect(finding.identifiers, <String>{'GHSA-1', 'CVE-2020-1'});
  });

  test('fingerprint is stable and ignores free text', () {
    const reworded = Finding(
      ruleId: 'GHSA-1',
      source: FindingSource.osv,
      severity: Severity.critical,
      title: 'A different summary',
      packageName: 'http',
      packageVersion: '0.13.0',
      location: SourceLocation('pubspec.lock'),
    );
    expect(finding.fingerprint, reworded.fingerprint);
    expect(finding.fingerprint, hasLength(64));
  });

  test('toJson omits absent optional values', () {
    final Map<String, Object?> json = finding.toJson();
    expect(json['severity'], 'high');
    expect(json.containsKey('fixedVersion'), isFalse);
    expect(json['file'], 'pubspec.lock');
  });

  test('SourceLocation renders path and line', () {
    expect('${const SourceLocation('a.dart', line: 3)}', 'a.dart:3');
    expect('${const SourceLocation('a.dart')}', 'a.dart');
  });
}
