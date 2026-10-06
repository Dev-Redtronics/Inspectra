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
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/typosquat/typosquat_report.dart';
import 'package:test/test.dart';

/// Tests the report of the `typosquat` command.
void main() {
  const plain = AnsiStyler(enabled: false);

  group('TyposquatReport', () {
    const typosquat = Finding(
      ruleId: 'LEVENSHTEIN_1',
      source: FindingSource.typosquat,
      severity: Severity.high,
      title: '"htttp" is one edit away from "http".',
      packageName: 'htttp',
      attributes: <String, Object?>{'matchedPublicPackage': 'http'},
    );
    const confusion = Finding(
      ruleId: 'DEPENDENCY_CONFUSION',
      source: FindingSource.confusion,
      severity: Severity.medium,
      title: '"internal_core" also exists on pub.dev.',
      packageName: 'internal_core',
      attributes: <String, Object?>{'publicVersion': '9.9.9'},
    );

    test('keeps the stable JSON fields', () {
      const report = TyposquatReport(
        pubspecPath: 'pubspec.yaml',
        packages: <String>['htttp', 'internal_core'],
        findings: <Finding>[typosquat, confusion],
        confusionChecked: true,
      );

      final Map<String, Object?> json = report.toJson();

      expect(report.command, 'typosquat');
      expect(json['packages'], <String>['htttp', 'internal_core']);
      expect(json['typosquatFindings'], <Object?>[
        <String, Object?>{
          'rule': 'LEVENSHTEIN_1',
          'severity': Severity.high.label,
          'description': typosquat.title,
          'localPackage': 'htttp',
          'matchedPublicPackage': 'http',
        },
      ]);
      expect(json['confusionFindings'], <Object?>[
        <String, Object?>{
          'rule': 'DEPENDENCY_CONFUSION',
          'severity': Severity.medium.label,
          'description': confusion.title,
          'packageName': 'internal_core',
          'publicVersion': '9.9.9',
        },
      ]);
    });

    test('fails when a finding reaches the threshold', () {
      const report = TyposquatReport(
        pubspecPath: 'pubspec.yaml',
        packages: <String>['internal_core'],
        findings: <Finding>[confusion],
        confusionChecked: true,
      );

      expect(report.isFailing(Severity.medium), isTrue);
      expect(report.isFailing(Severity.high), isFalse);
    });

    test('renders both sections', () {
      final out = StringBuffer();
      const TyposquatReport(
        pubspecPath: 'pubspec.yaml',
        packages: <String>['htttp', 'internal_core'],
        findings: <Finding>[typosquat, confusion],
        confusionChecked: true,
      ).writeText(out, plain);

      expect(out.toString(), contains('Typosquatting:'));
      expect(out.toString(), contains('Dependency Confusion:'));
      expect(out.toString(), contains('htttp  (LEVENSHTEIN_1)'));
      expect(out.toString(), contains('Typosquat / confusion findings: 2'));
    });

    test('renders a clean result and a skipped confusion check', () {
      final out = StringBuffer();
      const TyposquatReport(
        pubspecPath: 'pubspec.yaml',
        packages: <String>['http'],
        findings: <Finding>[],
        confusionChecked: false,
      ).writeText(out, plain);

      expect(out.toString(), contains('No typosquatting or confusion'));
      expect(out.toString(), contains('confusion check skipped'));
    });
  });
}
