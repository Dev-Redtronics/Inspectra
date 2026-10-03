import 'dart:convert';
import 'dart:io';

import 'package:inspectra/src/cli/inspectra_command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  late String root;
  late StringBuffer out;
  late StringBuffer err;

  Future<int> run(List<String> arguments) {
    out = StringBuffer();
    err = StringBuffer();
    return InspectraCommandRunner(
      out: out,
      err: err,
    ).run(['-C', root, ...arguments]);
  }

  setUp(() {
    root = temporaryDirectory();
    writeFile(
      root,
      'pubspec.yaml',
      'name: app\n'
          'environment:\n  sdk: ^3.0.0\n'
          'inspectra:\n  api:\n    enabled: true\n',
    );
    writeFile(
      root,
      '.dart_tool/package_config.json',
      jsonEncode({
        'configVersion': 2,
        'packages': [
          {
            'name': 'app',
            'rootUri': '../',
            'packageUri': 'lib/',
            'languageVersion': '3.0',
          },
        ],
      }),
    );
    writeFile(
      root,
      'lib/app.dart',
      "export 'src/impl.dart';\nint answer() => 42;\n",
    );
    writeFile(root, 'lib/src/impl.dart', 'class Impl {}\n');
  });

  test('api check asks for a dump when there is none', () async {
    expect(await run(['api', 'check']), checkFailedExitCode);
    expect(out.toString(), contains('dart run inspectra api dump'));
  });

  test('api dump records the API, and api check accepts it', () async {
    expect(await run(['api', 'dump']), 0);
    expect(
      File(p.join(root, 'api', 'app.api')).readAsStringSync(),
      contains('int answer();'),
    );

    expect(await run(['api', 'check']), 0);
    expect(out.toString(), contains('matches api/app.api'));
  });

  test('api check shows how the API changed', () async {
    await run(['api', 'dump']);
    writeFile(
      root,
      'lib/src/impl.dart',
      'class Impl {\n  void added() {}\n}\n',
    );

    expect(await run(['api', 'check']), checkFailedExitCode);
    expect(out.toString(), contains('+  void added();'));
  });

  test('check runs every enabled feature', () async {
    await run(['api', 'dump']);

    expect(await run(['check']), 0);
    expect(out.toString(), contains('The public API matches'));
  });

  test('reports a broken configuration', () async {
    writeFile(root, 'inspectra.yaml', 'api:\n  enabeld: true\n');

    expect(await run(['check']), errorExitCode);
    expect(err.toString(), contains('"api.enabeld"'));
  });

  test('rejects an unknown scan', () async {
    expect(await run(['trivy', 'malware']), usageExitCode);
    expect(err.toString(), contains('Unknown scan "malware"'));
  });

  test('says when Trivy is disabled', () async {
    expect(await run(['trivy']), 0);
    expect(out.toString(), contains('Trivy is disabled'));
  });

  group('trivy', testOn: 'posix', () {
    late FakeTrivy trivy;

    setUp(() {
      trivy = FakeTrivy(
        temporaryDirectory(),
        report: {
          'Results': [
            {
              'Target': 'lib/app.dart',
              'Class': 'secret',
              'Secrets': [
                {
                  'RuleID': 'github-pat',
                  'Severity': 'CRITICAL',
                  'Title': 'GitHub Personal Access Token',
                },
              ],
            },
          ],
        },
      );
      writeFile(
        root,
        'inspectra.yaml',
        'trivy:\n  enabled: true\n  executable: ${trivy.executable}\n',
      );
      writeFile(root, 'pubspec.lock', 'packages: {}\n');
    });

    test('runs every enabled scan and writes their reports', () async {
      expect(await run(['trivy']), checkFailedExitCode);
      expect(out.toString(), contains('Trivy secret scan: 1 finding(s).'));
      expect(
        out.toString(),
        contains('Trivy vulnerability scan: no findings.'),
      );
      expect(
        File(p.join(root, '.dart_tool/inspectra/trivy/secret.json'))
            .readAsStringSync(),
        contains('github-pat'),
      );
      expect(
        File(p.join(root, '.dart_tool/inspectra/trivy/license.json'))
            .existsSync(),
        isTrue,
      );
    });

    test('runs only the named scans', () async {
      expect(await run(['trivy', 'vulnerability']), 0);
      expect(out.toString(), isNot(contains('secret')));
      expect(trivy.arguments, containsAllInOrder(['--scanners', 'vuln']));
    });

    test('runs the filesystem scan on the package itself', () async {
      expect(await run(['trivy', 'filesystem']), checkFailedExitCode);
      expect(
        trivy.arguments,
        containsAllInOrder(['--skip-dirs', '.dart_tool']),
      );
      expect(trivy.arguments.last, root);
    });
  });

  test('coverage runs the tests and checks the threshold', () async {
    final String package = Directory.current.path;
    writeFile(
      root,
      'pubspec.yaml',
      'name: app\n'
          'environment:\n  sdk: ^3.0.0\n'
          'dev_dependencies:\n  test: any\n'
          'inspectra:\n'
          '  coverage:\n    enabled: true\n    min_line_coverage: 70\n',
    );
    writeFile(
      root,
      'lib/src/impl.dart',
      'int covered() => 1;\nint uncovered() => 2;\n',
    );
    writeFile(root, 'lib/unused.dart', 'int unused() => 3;\n');
    writeFile(
      root,
      'lib/ignored.dart',
      '// coverage:ignore-file\nint ignored() => 4;\n',
    );
    writeFile(
      root,
      'test/app_test.dart',
      "import 'package:app/app.dart';\n"
          "import 'package:app/src/impl.dart';\n"
          "import 'package:test/test.dart';\n"
          "void main() => test('covers', () {\n"
          '  expect(answer() + covered(), 43);\n'
          '});\n',
    );
    final ProcessResult pubGet = await Process.run(
      Platform.resolvedExecutable,
      ['pub', 'get', '--offline'],
      workingDirectory: root,
    );
    expect(pubGet.exitCode, 0, reason: '${pubGet.stderr}');

    expect(await run(['coverage']), checkFailedExitCode);
    expect(out.toString(), contains('below the required 70.00%'));
    expect(out.toString(), contains('lib/unused.dart'));
    expect(out.toString(), isNot(contains('lib/ignored.dart')));
    expect(
      File(p.join(root, 'coverage', 'lcov.info')).readAsStringSync(),
      contains('SF:lib/app.dart'),
    );

    expect(await run(['coverage', '--min', '50']), 0);
    expect(Directory.current.path, package);
  }, tags: ['slow']);
}
