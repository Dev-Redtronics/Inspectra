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
import 'package:inspectra/src/typosquat/levenshtein.dart';
import 'package:inspectra/src/typosquat/typosquat_detector.dart';
import 'package:test/test.dart';

/// Tests typosquatting detection, including the false positives of
/// `dart_audit`.
void main() {
  /// Analyses [names] and returns `name:rule` pairs.
  List<String> analyze(List<String> names, {List<String> allow = const []}) =>
      TyposquatDetector(allow: allow)
          .analyze(names, locate: (_) => const SourceLocation('pubspec.yaml'))
          .map((f) => '${f.packageName}:${f.ruleId}')
          .toList();

  test('levenshtein distance with early exit', () {
    expect(levenshteinDistance('kitten', 'sitting'), 3);
    expect(levenshteinDistance('http', 'http'), 0);
    expect(levenshteinDistance('a', 'abcdef', limit: 2), 3);
  });

  test('detects typos of popular packages', () {
    expect(analyze(<String>['htpp']), <String>['htpp:LEVENSHTEIN_1']);
    expect(analyze(<String>['providr']), <String>['providr:LEVENSHTEIN_1']);
    expect(analyze(<String>['proivder']), <String>['proivder:LEVENSHTEIN_2']);
  });

  test('reports the closest popular package', () {
    final finding = TyposquatDetector().analyze(<String>[
      'fluter_hooks',
    ], locate: (_) => const SourceLocation('pubspec.yaml')).single;
    expect(finding.attributes['matchedPublicPackage'], 'flutter_hooks');
    expect(finding.severity, Severity.critical);
  });

  test('detects affix wrapping and suspicious suffixes', () {
    expect(analyze(<String>['flutter_dio']), <String>[
      'flutter_dio:PREFIX_FLUTTER',
    ]);
    expect(analyze(<String>['dart_provider']), <String>[
      'dart_provider:PREFIX_DART_PUB',
    ]);
    expect(analyze(<String>['provider_xz']), <String>[
      'provider_xz:SUSPICIOUS_SUFFIX',
    ]);
  });

  test('does not report the false positives of dart_audit', () {
    expect(
      analyze(<String>[
        'lints',
        'sqlite3',
        'http2',
        'flutter_bloc',
        'bloc_test',
        'yaml_edit',
        'drift_dev',
        'riverpod_lint',
        'provider',
      ]),
      isEmpty,
    );
  });

  test('honours the allow list', () {
    expect(analyze(<String>['htpp'], allow: <String>['htpp']), isEmpty);
  });
}
