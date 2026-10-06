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

import 'dart:convert';
import 'dart:io';

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/rules/rule_catalog.dart';
import 'package:inspectra/src/rules/rule_info.dart';
import 'package:test/test.dart';

import '../support/test_harness.dart';

/// Tests the rule catalog and `inspectra explain`.
void main() {
  /// The directories and files whose code reports findings.
  const reporters = <String>[
    'lib/src/inspect',
    'lib/src/trust',
    'lib/src/typosquat',
    'lib/src/deps',
    'lib/src/workspace',
    'lib/src/config_tools/config_lint.dart',
    'lib/src/api/semver_result.dart',
    'lib/src/dashboard/section_adapters.dart',
  ];

  /// Upper case texts in those files that are no rule ids.
  const notRules = <String>{
    'CRITICAL',
    'HIGH',
    'MEDIUM',
    'UNKNOWN',
    'CLEAN',
    'TRUSTED',
    'SUSPICIOUS',
    'HEAD',
    'LC_ALL',
    'INSPECTRA_CONFIG',
    'INSPECTRA_TRIVY',
    'INSPECTRA_DEBUG',
    'INSPECTRA_CACHE_DIR',
  };

  /// Collects the upper case literals of the files that report findings.
  ///
  /// Returns them.
  Set<String> literals() {
    final files = <File>[
      for (final path in reporters)
        if (FileSystemEntity.isDirectorySync(path))
          ...Directory(path).listSync(recursive: true).whereType<File>(),
      for (final path in reporters)
        if (FileSystemEntity.isFileSync(path)) File(path),
    ];
    final pattern = RegExp("'([A-Z][A-Z0-9]{3,}(?:_[A-Z0-9]+)*)'");
    return <String>{
      for (final file in files)
        for (final RegExpMatch match in pattern.allMatches(
          file.readAsStringSync(),
        ))
          ?match[1],
    }..removeAll(notRules);
  }

  test('every rule id of the code is in the catalog, once', () {
    final List<RuleInfo> catalog = ruleCatalog();
    final ids = <String>[for (final rule in catalog) rule.id];
    expect(ids.toSet(), hasLength(ids.length));
    expect(literals().difference(ids.toSet()), isEmpty);
    final String sources = <String>[
      for (final File file in Directory(
        'lib/src',
      ).listSync(recursive: true).whereType<File>())
        if (!file.path.endsWith('rule_catalog.dart')) file.readAsStringSync(),
    ].join();
    final stale = <String>[
      for (final rule in catalog)
        if (rule.source != FindingSource.style &&
            !sources.contains("'${rule.id}'"))
          rule.id,
    ];
    expect(stale, isEmpty);
    expect(findRule('missing_upper_bound')?.severity, Severity.medium);
    expect(findRule('no_else')?.source, FindingSource.style);
    expect(findRule('PROCESS_RUN')?.source, FindingSource.regex);
  });

  group('explain', () {
    final harnesses = <TestHarness>[];
    tearDown(() {
      for (final harness in harnesses) {
        harness.dispose();
      }
      harnesses.clear();
    });

    /// Runs `inspectra explain` with [arguments] in a fresh harness.
    ///
    /// Returns the harness after the run and the exit code.
    Future<(TestHarness, int)> explain(List<String> arguments) async {
      final harness = TestHarness.withFiles(const <String, String>{});
      harnesses.add(harness);
      final int code = await harness.run(<String>['explain', ...arguments]);
      return (harness, code);
    }

    test('explains a rule in every format', () async {
      final (TestHarness text, int textCode) = await explain(<String>[
        'missing_upper_bound',
      ]);
      expect(textCode, 0);
      expect(text.out, startsWith('MISSING_UPPER_BOUND (pubspec, medium)\n'));
      expect(text.out, contains('inspectra deps --fix'));
      final (TestHarness json, _) = await explain(<String>[
        'LAYER_VIOLATION',
        '-f',
        'json',
      ]);
      final rule = jsonDecode(json.out) as Map<String, Object?>;
      expect(rule['source'], 'workspace');
      final (TestHarness markdown, _) = await explain(<String>[
        'no_else',
        '-f',
        'markdown',
      ]);
      expect(markdown.out, startsWith('## no_else\n'));
    });

    test('lists every rule and points advisories to OSV.dev', () async {
      final (TestHarness list, int code) = await explain(const <String>[]);
      expect(code, 0);
      expect(
        list.out.split('\n').where((line) => line.isNotEmpty).length,
        ruleCatalog().length,
      );
      final (TestHarness advisory, int advisoryCode) = await explain(<String>[
        'GHSA-abcd-efgh-ijkl',
      ]);
      expect(advisoryCode, 0);
      expect(
        advisory.out,
        contains('https://osv.dev/vulnerability/GHSA-ABCD-EFGH-IJKL'),
      );
      final (TestHarness unknown, int unknownCode) = await explain(<String>[
        'MISSING_UPPER_BOUNDS',
      ]);
      expect(unknownCode, 64);
      expect(unknown.err, contains('Did you mean "MISSING_UPPER_BOUND"?'));
    });
  });
}
