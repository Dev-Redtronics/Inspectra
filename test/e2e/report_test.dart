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

import 'package:test/test.dart';
import 'package:xml/xml.dart';

import '../support/test_harness.dart';

/// Runs `inspectra report` and the CI formats of the other commands
/// in-process.
void main() {
  final harnesses = <TestHarness>[];

  tearDown(() {
    for (final harness in harnesses) {
      harness.dispose();
    }
    harnesses.clear();
  });

  const pubspec = '''
name: demo
version: 1.2.0
environment:
  sdk: ^3.6.0
inspectra:
  style:
    enabled: true
    rules:
      no_else: true
  dependency_policy:
    enabled: true
    require_publish_to: true
''';

  const dirty = '''
int f(bool a) {
  if (a) {
    return 1;
  } else {
    return 2;
  }
}
''';

  /// Creates a package with style and dependency policy findings, plus
  /// [files].
  TestHarness project([Map<String, String> files = const <String, String>{}]) {
    final harness = TestHarness.withFiles(<String, String>{
      'pubspec.yaml': pubspec,
      'lib/demo.dart': dirty,
      ...files,
    });
    harnesses.add(harness);
    return harness;
  }

  /// Returns the content of [path] in the project of [harness].
  String read(TestHarness harness, String path) =>
      File('${harness.workingDirectory}/$path').readAsStringSync();

  test('reports every evaluation as HTML and further formats', () async {
    final TestHarness harness = project();
    final int code = await harness.run(<String>[
      'report',
      '--skip',
      'scan',
      '-f',
      'html',
      '-o',
      'build/report.html',
      '--also',
      'junit=build/junit.xml',
      '--also',
      'json=build/report.json',
    ]);
    expect(code, 1, reason: harness.err);
    final String html = read(harness, 'build/report.html');
    expect(html, startsWith('<!DOCTYPE html>'));
    expect(html, contains('<h1>demo 1.2.0</h1>'));
    expect(html, contains('MISSING_PUBLISH_TO'));
    expect(html, contains('no_else'));
    expect(html, contains('Not enabled; set coverage.enabled: true'));
    expect(html, contains('Not enabled; set api.semver: true'));
    expect(html, contains('Code lines, no comments'));
    final json =
        jsonDecode(read(harness, 'build/report.json')) as Map<String, Object?>;
    expect(json['command'], 'report');
    expect(json['project'], 'demo 1.2.0');
    expect(json['status'], 'failed');
    final sections = <String, Object?>{
      for (final Object? section in json['sections']! as List<Object?>)
        if (section case {
          'id': final String id,
          'status': final Object? status,
        })
          id: status,
    };
    expect(sections, <String, Object?>{
      'codebase': 'passed',
      'scan': 'skipped',
      'deps': 'failed',
      'config': 'passed',
      'format': 'skipped',
      'lint': 'skipped',
      'style': 'failed',
      'api': 'skipped',
      'semver': 'skipped',
      'changelog': 'skipped',
      'trivy': 'skipped',
      'coverage': 'skipped',
    });
    final junit = XmlDocument.parse(read(harness, 'build/junit.xml'));
    expect(junit.rootElement.getAttribute('failures'), '2');
    expect(harness.err, contains('Report written to build/junit.xml'));
  });

  test('prints a text overview and passes a clean package', () async {
    final TestHarness harness = project(<String, String>{
      'pubspec.yaml': 'name: demo\npublish_to: none\n',
      'lib/demo.dart': 'int f() => 1;\n',
    });
    expect(
      await harness.run(<String>['report', '--skip', 'scan']),
      0,
      reason: harness.err,
    );
    expect(harness.out, contains('[PASSED]  Dependencies'));
    expect(harness.out, contains('[SKIPPED] Supply chain'));
    expect(harness.out, contains('Overall: [PASSED]'));
  });

  test(
    'writes the report and exits with 69 when a section cannot run',
    () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.lock': 'packages: {}\n',
        'inspectra.yaml': 'trivy:\n  enabled: true\n',
      });
      final int code = await harness.run(<String>[
        'report',
        '--skip',
        'scan,style,deps',
        '--offline',
        '--trivy-mode',
        'required',
        '--exit-zero',
        '-f',
        'html',
        '-o',
        'report.html',
      ]);
      expect(code, 69);
      expect(harness.err, contains('The report is incomplete: Trivy secret'));
      final String html = read(harness, 'report.html');
      expect(html, contains('id="section-trivy-secret" open'));
      expect(html, contains('Overall: Error'));
    },
  );

  test('merges JSON reports of several runs', () async {
    final TestHarness harness = project();
    expect(
      await harness.run(<String>['deps', '-f', 'json', '-o', 'deps.json']),
      1,
    );
    expect(
      await harness.run(<String>[
        'report',
        '--skip',
        'scan,deps',
        '-f',
        'json',
        '-o',
        'report.json',
      ]),
      1,
    );
    final int code = await harness.run(<String>[
      'report',
      '--merge',
      'report.json',
      '--merge',
      'deps.json',
      '-f',
      'json',
      '-o',
      'merged.json',
    ]);
    expect(code, 1);
    final merged = jsonDecode(read(harness, 'merged.json')) as Map;
    final ids = <Object?>[
      for (final Object? section in merged['sections']! as List<Object?>)
        (section! as Map)['id'],
    ];
    expect(ids, contains('deps'));
    expect(ids, contains('style'));
    expect(ids, contains('deps-2'));
    expect(merged['project'], 'demo 1.2.0');
    expect(
      await harness.run(<String>['report', '--merge', 'lib/demo.dart']),
      65,
    );
    expect(
      await harness.run(<String>['report', '--merge', 'missing.json']),
      65,
    );
  });

  test('rejects a malformed --also', () async {
    final TestHarness harness = project();
    expect(await harness.run(<String>['report', '--also', 'pdf=a.pdf']), 64);
    expect(harness.err, contains('expected <format>=<path>'));
    expect(await harness.run(<String>['report', '--also', 'html']), 64);
  });

  test('every command speaks the CI formats', () async {
    final TestHarness harness = project();
    expect(await harness.run(<String>['deps', '-f', 'gitlab']), 1);
    final issues = jsonDecode(harness.out) as List<Object?>;
    expect((issues.single! as Map)['check_name'], 'MISSING_PUBLISH_TO');
    (harness.context.out as StringBuffer).clear();
    expect(await harness.run(<String>['deps', '-f', 'checkstyle']), 1);
    expect(
      XmlDocument.parse(harness.out).findAllElements('error'),
      hasLength(1),
    );
    (harness.context.out as StringBuffer).clear();
    expect(await harness.run(<String>['deps', '-f', 'sonarqube']), 1);
    expect((jsonDecode(harness.out) as Map)['issues'], hasLength(1));
    (harness.context.out as StringBuffer).clear();
    expect(await harness.run(<String>['style', '-f', 'html']), 1);
    expect(harness.out, contains('no_else'));
  });
}
