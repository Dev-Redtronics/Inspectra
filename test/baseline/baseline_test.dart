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

import 'dart:io';

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/baseline/baseline.dart';
import 'package:inspectra/src/baseline/baseline_candidate.dart';
import 'package:inspectra/src/baseline/baseline_entry.dart';
import 'package:inspectra/src/baseline/baseline_scope.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/fixtures.dart';

/// Tests reading, updating and writing the baseline file.
void main() {
  /// Creates a style candidate of [rule] in [path] at [line].
  BaselineCandidate style(
    String rule,
    String path, {
    int line = 1,
    Severity severity = Severity.low,
    String title = 'message',
  }) => BaselineCandidate(
    scope: BaselineScope.style,
    source: 'style',
    rule: rule,
    severity: severity,
    title: title,
    path: path,
    line: line,
  );

  /// Creates an entry of [scope] for [rule] in [path] covering [count].
  BaselineEntry entry(
    BaselineScope scope,
    String rule,
    String path, {
    int count = 1,
  }) => BaselineEntry(
    scope: scope,
    source: scope.id,
    rule: rule,
    count: count,
    severity: Severity.low,
    title: 'message',
    path: path,
  );

  /// Selects the entries of the style scope.
  bool styleOnly(BaselineEntry entry) => entry.scope == BaselineScope.style;

  group('record', () {
    test('counts the findings of a key with their worst severity', () {
      final Baseline baseline = Baseline(const <BaselineEntry>[])
          .record(styleOnly, <BaselineCandidate>[
            style('no_else', 'lib/a.dart', line: 9, title: 'second'),
            style(
              'no_else',
              'lib/a.dart',
              line: 3,
              severity: Severity.high,
              title: 'first\u202E',
            ),
            style('no_else', 'lib/b.dart'),
          ]);
      expect(baseline.entries, hasLength(2));
      final BaselineEntry first = baseline.entries.first;
      expect(first.path, 'lib/a.dart');
      expect(first.count, 2);
      expect(first.severity, Severity.high);
      expect(first.title, r'first\u{202E}');
      expect(baseline.countOf(BaselineScope.style), 3);
    });

    test('replaces only the entries of the covered scopes', () {
      final baseline = Baseline(<BaselineEntry>[
        entry(BaselineScope.lint, 'unused_import', 'lib/a.dart'),
        entry(BaselineScope.style, 'no_else', 'lib/old.dart'),
      ]);
      final Baseline updated = baseline.record(styleOnly, <BaselineCandidate>[
        style('no_else', 'lib/new.dart'),
      ]);
      expect(updated.entries.map((e) => e.path), <String>[
        'lib/a.dart',
        'lib/new.dart',
      ]);
    });
  });

  group('prune', () {
    test('lowers counts, removes fixed entries and never adds', () {
      final baseline = Baseline(<BaselineEntry>[
        entry(BaselineScope.style, 'no_else', 'lib/a.dart', count: 3),
        entry(BaselineScope.style, 'no_else', 'lib/b.dart'),
        entry(BaselineScope.lint, 'unused_import', 'lib/c.dart'),
      ]);
      final Baseline pruned = baseline.prune(styleOnly, <BaselineCandidate>[
        style('no_else', 'lib/a.dart'),
        style('no_else', 'lib/new.dart'),
      ]);
      expect(pruned.entries.map((e) => '${e.path}:${e.count}'), <String>[
        'lib/c.dart:1',
        'lib/a.dart:1',
      ]);
    });

    test('keeps a count that is still reached', () {
      final baseline = Baseline(<BaselineEntry>[
        entry(BaselineScope.style, 'no_else', 'lib/a.dart', count: 2),
      ]);
      final Baseline pruned = baseline.prune(styleOnly, <BaselineCandidate>[
        style('no_else', 'lib/a.dart'),
        style('no_else', 'lib/a.dart', line: 5),
        style('no_else', 'lib/a.dart', line: 7),
      ]);
      expect(pruned.entries.single.count, 2);
    });
  });

  group('file', () {
    test('renders sorted entries without timestamps and reads them back', () {
      final baseline = Baseline(<BaselineEntry>[
        entry(BaselineScope.style, 'no_else', 'lib/b.dart'),
        const BaselineEntry(
          scope: BaselineScope.scan,
          source: 'osv',
          rule: 'GHSA-1',
          count: 1,
          severity: Severity.medium,
          title: 'advisory',
          package: 'http',
          path: 'pubspec.lock',
        ),
      ]);
      final String text = baseline.render();
      expect(text, endsWith('}\n'));
      expect(text, isNot(contains('generatedAt')));
      final parsed = Baseline.parse(text, 'baseline.json');
      expect(parsed.render(), text);
      expect(parsed.entries.first.package, 'http');
    });

    test('loads a missing file as empty and writes atomically', () {
      final String directory = temporaryDirectory();
      final String path = p.join(directory, 'nested', 'baseline.json');
      expect(Baseline.load(path).isEmpty, isTrue);
      Baseline(<BaselineEntry>[
        entry(BaselineScope.style, 'no_else', 'lib/a.dart'),
      ]).write(path);
      expect(Baseline.load(path).entries.single.rule, 'no_else');
      expect(File('$path.tmp').existsSync(), isFalse);
    });

    for (final (String text, String message) in <(String, String)>[
      ('not json', 'no valid JSON'),
      ('[]', 'must be a JSON object'),
      ('{"schemaVersion": 2, "entries": []}', 'schemaVersion 2'),
      ('{"schemaVersion": 1}', '"entries" list'),
      ('{"schemaVersion": 1, "entries": [1]}', 'must be an object'),
      (
        '{"schemaVersion": 1, "entries": [{"scope": "x", "source": "s", '
            '"rule": "r", "count": 1, "severity": "low", "title": "t"}]}',
        'unknown scope "x"',
      ),
      (
        '{"schemaVersion": 1, "entries": [{"scope": "lint", "source": "s", '
            '"rule": "r", "count": 0, "severity": "low", "title": "t"}]}',
        '"count" of at least 1',
      ),
      (
        '{"schemaVersion": 1, "entries": [{"scope": "lint", "source": "s", '
            '"rule": "r", "count": 1, "severity": "bad", "title": "t"}]}',
        'unknown severity "bad"',
      ),
      (
        '{"schemaVersion": 1, "entries": [{"scope": "lint", "source": "s", '
            '"rule": "r", "count": 1, "severity": "low", "title": "t", '
            '"line": 3}]}',
        'unknown field "line"',
      ),
      (
        '{"schemaVersion": 1, "entries": [{"scope": "lint", "source": "s", '
            '"count": 1, "severity": "low", "title": "t"}]}',
        'needs a "rule" text',
      ),
      (
        '{"schemaVersion": 1, "entries": [{"scope": "lint", "source": "s", '
            '"rule": "r", "count": 1, "severity": "low", "title": "t", '
            '"path": 3}]}',
        '"path" that is no text',
      ),
    ]) {
      test('rejects a malformed file: $message', () {
        expect(
          () => Baseline.parse(text, 'baseline.json'),
          throwsA(
            isA<InvalidInputException>().having(
              (e) => e.message,
              'message',
              allOf(contains('baseline.json'), contains(message)),
            ),
          ),
        );
      });
    }
  });
}
