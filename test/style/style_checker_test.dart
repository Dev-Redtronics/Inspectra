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

import 'dart:convert';

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/report/output_format.dart';
import 'package:inspectra/src/report/report_renderer.dart';
import 'package:inspectra/src/style/rules/no_else_rule.dart';
import 'package:inspectra/src/style/style_checker.dart';
import 'package:inspectra/src/style/style_report.dart';
import 'package:inspectra/src/style/style_suppressions.dart';
import 'package:inspectra/style.dart';
import 'package:test/test.dart';

/// Tests the checker, suppressions, results and reports.
void main() {
  const source = '''
int a(bool x) {
  if (x) { return 1; } else { return 2; }
}
int b(bool x) {
  // inspectra: ignore-style no_else
  if (x) { return 1; } else { return 2; }
}
int c(bool x) {
  if (x) { return 1; } else { return 2; } // inspectra: ignore-style no_else
}
''';

  group('StyleSuppressions', () {
    test('suppresses the next or the same line, per rule', () {
      final List<StyleViolation> violations = const StyleChecker(<StyleRule>[
        NoElseRule(),
      ]).checkSource('lib/a.dart', source);
      expect(violations.map((v) => v.line), <int>[2]);
    });

    test('suppresses rules in the whole file', () {
      final suppressions = StyleSuppressions.parse(
        '// inspectra: ignore-style-file no_else, public_docs\r\nvoid f() {}',
      );
      expect(suppressions.fileRules, <String>{'no_else', 'public_docs'});
      expect(
        suppressions.suppresses(
          const StyleViolation(
            ruleId: 'public_docs',
            path: 'a',
            line: 9,
            column: 1,
            message: 'm',
          ),
        ),
        isTrue,
      );
      expect(
        suppressions.suppresses(
          const StyleViolation(
            ruleId: 'no_comments',
            path: 'a',
            line: 9,
            column: 1,
            message: 'm',
          ),
        ),
        isFalse,
      );
    });

    test('needs rule names', () {
      final suppressions = StyleSuppressions.parse(
        '// inspectra: ignore-style\nvoid f() {}',
      );
      expect(suppressions.lineRules, isEmpty);
    });
  });

  group('StyleChecker', () {
    test('checks files with syntax errors as far as possible', () {
      final List<StyleViolation> violations = const StyleChecker(
        <StyleRule>[NoElseRule()],
      ).checkSource('lib/a.dart', 'void f() { if (true) {} else {} }\nclass {');
      expect(violations, hasLength(1));
    });

    test('sorts by path, line, column and rule', () {
      const a = StyleViolation(
        ruleId: 'b',
        path: 'a',
        line: 1,
        column: 1,
        message: '',
      );
      const b = StyleViolation(
        ruleId: 'a',
        path: 'a',
        line: 1,
        column: 1,
        message: '',
      );
      const c = StyleViolation(
        ruleId: 'a',
        path: 'a',
        line: 1,
        column: 2,
        message: '',
      );
      const d = StyleViolation(
        ruleId: 'a',
        path: 'a',
        line: 2,
        column: 1,
        message: '',
      );
      const e = StyleViolation(
        ruleId: 'a',
        path: 'b',
        line: 1,
        column: 1,
        message: '',
      );
      expect(
        (<StyleViolation>[e, d, c, a, b]..sort(compareStyleViolations)),
        <StyleViolation>[b, a, c, d, e],
      );
    });
  });

  group('StyleViolation', () {
    test('round-trips through JSON', () {
      const violation = StyleViolation(
        ruleId: 'no_else',
        path: 'lib/a.dart',
        line: 3,
        column: 5,
        message: 'No else.',
      );
      final copy = StyleViolation.fromJson(
        jsonDecode(jsonEncode(violation.toJson())),
      );
      expect('$copy', 'lib/a.dart:3:5: No else. [no_else]');
      expect(() => StyleViolation.fromJson(1), throwsFormatException);
      expect(
        () => StyleViolation.fromJson(<String, Object?>{'rule': 1}),
        throwsFormatException,
      );
    });
  });

  group('StyleResult and StyleReport', () {
    const violation = StyleViolation(
      ruleId: 'no_else',
      path: 'lib/a.dart',
      line: 3,
      column: 5,
      message: 'No else: return early instead.',
    );

    test('renders a passing and a failing check', () {
      final passing = StyleResult(
        checked: 4,
        rules: const <String>['no_else'],
        violations: const <StyleViolation>[],
        failOnFindings: true,
      );
      expect(passing.render(), 'Style: all 4 file(s) follow the 1 rule(s).');
      final failing = StyleResult(
        checked: 4,
        rules: const <String>['no_else'],
        violations: const <StyleViolation>[violation, violation],
        failOnFindings: true,
      );
      expect(failing.failed, isTrue);
      expect(failing.affectedFiles, 1);
      expect(
        failing.render(),
        startsWith(
          'Style: 2 violation(s) in 1 of 4 file(s).\n'
          '  lib/a.dart:3:5: No else: return early instead. [no_else]',
        ),
      );
      final lenient = StyleResult(
        checked: 4,
        rules: const <String>['no_else'],
        violations: const <StyleViolation>[violation],
        failOnFindings: false,
      );
      expect(lenient.failed, isFalse);
      expect(lenient.render(), contains('(not failing)'));
      expect(lenient.toJson()['violations'], hasLength(1));
    });

    test('reports violations as style findings, also in SARIF', () {
      final report = StyleReport(
        StyleResult(
          checked: 1,
          rules: const <String>['no_else'],
          violations: const <StyleViolation>[violation],
          failOnFindings: true,
        ),
      );
      expect(report.command, 'style');
      expect(report.isFailing(Severity.critical), isTrue);
      final Finding finding = report.findings.single;
      expect(finding.source, FindingSource.style);
      expect(finding.location?.line, 3);
      final out = StringBuffer();
      report.writeText(out, const AnsiStyler(enabled: false));
      expect('$out', contains('[no_else]'));
      final sarif = jsonDecode(
        const ReportRenderer().render(
          report,
          OutputFormat.sarif,
          style: const AnsiStyler(enabled: false),
          generatedAt: DateTime.utc(2026),
        ),
      ) as Map<String, Object?>;
      final String text = jsonEncode(sarif);
      expect(text, contains('maintainability'));
      expect(text, isNot(contains('security-severity')));
    });
  });
}
