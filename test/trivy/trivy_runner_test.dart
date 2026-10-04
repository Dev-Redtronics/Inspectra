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
import 'package:inspectra/src/trivy/trivy_runner.dart';
import 'package:test/test.dart';

import '../support/fake_process_runner.dart';

/// Tests how Trivy failures are reported.
void main() {
  /// Scans with a fake Trivy answering [outcome].
  Future<List<Finding>> scan(ProcessOutcome outcome) => TrivyRunner(
    config: const TrivyConfig(),
    processRunner: FakeProcessRunner((_, _) => outcome),
  ).scan('trivy', '/project', displayPrefix: '.');

  test('maps a successful run', () async {
    final List<Finding> findings = await scan(
      const ProcessOutcome(exitCode: 0, stdout: '{"Results":[]}', stderr: ''),
    );
    expect(findings, isEmpty);
  });

  test('treats non-zero exit codes as tool failures, never as findings', () {
    expect(
      scan(const ProcessOutcome(exitCode: 1, stdout: '', stderr: 'db error')),
      throwsA(
        isA<UnavailableException>().having(
          (e) => e.message,
          'message',
          contains('db error'),
        ),
      ),
    );
  });

  test('rejects output that is not a JSON report', () {
    expect(
      scan(const ProcessOutcome(exitCode: 0, stdout: 'oops', stderr: '')),
      throwsA(isA<UnavailableException>()),
    );
    expect(
      scan(const ProcessOutcome(exitCode: 0, stdout: '[]', stderr: '')),
      throwsA(isA<UnavailableException>()),
    );
  });
}
