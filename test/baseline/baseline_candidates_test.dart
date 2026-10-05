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
import 'package:inspectra/src/baseline/baseline_candidate.dart';
import 'package:inspectra/src/baseline/baseline_candidates.dart';
import 'package:inspectra/src/baseline/baseline_scope.dart';
import 'package:test/test.dart';

/// Tests how findings of every check become baseline candidates.
void main() {
  test('a supply-chain finding is keyed without its version and line', () {
    BaselineCandidate candidate(String version, int line) => findingCandidate(
      Finding(
        ruleId: 'GHSA-1',
        source: FindingSource.osv,
        severity: Severity.medium,
        title: 'advisory',
        packageName: 'http',
        packageVersion: version,
        location: SourceLocation('pubspec.lock', line: line),
      ),
    );
    final BaselineCandidate old = candidate('0.13.0', 3);
    expect(old.scope, BaselineScope.scan);
    expect(old.key, 'scan|osv|GHSA-1|http|pubspec.lock');
    expect(candidate('0.13.1', 9).key, old.key);
  });

  test('lint diagnostics map their level to a severity', () {
    Severity severity(LintLevel level) => lintCandidate(
      LintIssue(
        severity: level,
        type: 'LINT',
        code: 'unused_import',
        path: 'lib/a.dart',
        line: 1,
        column: 1,
        message: 'Unused import.',
      ),
    ).severity;
    expect(severity(LintLevel.error), Severity.high);
    expect(severity(LintLevel.warning), Severity.medium);
    expect(severity(LintLevel.info), Severity.low);
    expect(severity(LintLevel.none), Severity.unknown);
  });

  test('paths use forward slashes on every platform', () {
    final BaselineCandidate candidate = styleCandidate(
      const StyleViolation(
        ruleId: 'no_else',
        path: r'lib\src\a.dart',
        line: 2,
        column: 1,
        message: 'No else.',
      ),
    );
    expect(candidate.path, 'lib/src/a.dart');
    expect(candidate.key, 'style|style|no_else||lib/src/a.dart');
  });

  test('a Trivy package target loses its version, a file target stays', () {
    BaselineCandidate candidate(String target) => scanCandidate(
      'license',
      ScanFinding(
        severity: Severity.high,
        target: target,
        id: 'GPL-3.0',
        title: 'license',
      ),
    );
    final BaselineCandidate package = candidate('left_pad 1.2.3');
    expect(package.package, 'left_pad');
    expect(package.path, isNull);
    expect(package.scope, BaselineScope.trivy);
    expect(package.source, 'license');
    expect(candidate('lib/keys.dart').path, 'lib/keys.dart');
    expect(candidate('notes final').path, 'notes final');
  });
}
