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
import 'package:inspectra/src/hook/hook_report.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:test/test.dart';

/// Tests the report of the `hook` command.
void main() {
  const plain = AnsiStyler(enabled: false);

  group('HookReport', () {
    test('never fails and serialises the action', () {
      const report = HookReport(
        action: 'install',
        path: '.git/hooks/pre-commit',
        changed: true,
        message: 'Installed the pre-commit hook.',
      );
      final out = StringBuffer();
      report.writeText(out, plain);

      expect(report.command, 'hook');
      expect(report.findings, isEmpty);
      expect(report.isFailing(Severity.unknown), isFalse);
      expect(report.toJson(), <String, Object?>{
        'action': 'install',
        'path': '.git/hooks/pre-commit',
        'changed': true,
        'message': 'Installed the pre-commit hook.',
      });
      expect(out.toString(), contains('✔ Installed the pre-commit hook.'));
    });
  });
}
