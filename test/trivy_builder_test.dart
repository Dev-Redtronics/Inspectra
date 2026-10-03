@TestOn('posix')
library;

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inspectra/builder.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

const Map<String, List<Map<String, Object>>> _secretReport = {
  'Results': [
    {
      'Target': 'lib/a.dart',
      'Class': 'secret',
      'Secrets': [
        {
          'RuleID': 'github-pat',
          'Severity': 'CRITICAL',
          'Title': 'GitHub Personal Access Token',
          'StartLine': 1,
        },
      ],
    },
  ],
};

String _pubspec(String executable, {String extra = ''}) =>
    '''
name: a
inspectra:
  trivy:
    enabled: true
    executable: $executable
$extra''';

void main() {
  late String directory;

  setUp(() => directory = temporaryDirectory());

  test(
    'runs the secret scan on the build sources and fails on findings',
    () async {
      final trivy = FakeTrivy(directory, report: _secretReport);

      final TestBuilderResult result = await testBuilder(
        secretScanBuilder(BuilderOptions.empty),
        {
          'a|pubspec.yaml': _pubspec(trivy.executable),
          'a|lib/a.dart': 'const token = "...";',
          'a|lib/b.txt': 'other',
        },
        rootPackage: 'a',
        outputs: {
          'a|inspectra/trivy/secret.json': decodedMatches(
            contains('"failed": true'),
          ),
        },
      );

      expect(result.succeeded, isFalse);
      expect(trivy.scannedFiles, containsAll(['lib/a.dart', 'pubspec.yaml']));
      expect(trivy.scannedFiles, isNot(contains('lib/b.txt')));
    },
  );

  test('only warns when findings do not fail the scan', () async {
    final trivy = FakeTrivy(directory, report: _secretReport);

    final TestBuilderResult result = await testBuilder(
      secretScanBuilder(BuilderOptions.empty),
      {
        'a|pubspec.yaml': _pubspec(
          trivy.executable,
          extra: '    secret:\n      fail_on_findings: false\n',
        ),
        'a|lib/a.dart': 'const token = "...";',
      },
      rootPackage: 'a',
      outputs: {
        'a|inspectra/trivy/secret.json': decodedMatches(
          contains('"failed": false'),
        ),
      },
    );

    expect(result.succeeded, isTrue);
  });

  test('skips scans that do not run on build', () async {
    final trivy = FakeTrivy(directory);

    await testBuilder(
      vulnerabilityScanBuilder(BuilderOptions.empty),
      {
        'a|pubspec.yaml': _pubspec(trivy.executable),
        'a|pubspec.lock': 'packages: {}\n',
      },
      rootPackage: 'a',
      outputs: {},
    );
  });

  test(
    'scans the lock file when the vulnerability scan runs on build',
    () async {
      final trivy = FakeTrivy(directory);

      await testBuilder(
        vulnerabilityScanBuilder(BuilderOptions.empty),
        {
          'a|pubspec.yaml': _pubspec(
            trivy.executable,
            extra: '    vulnerability:\n      run_on_build: true\n',
          ),
          'a|pubspec.lock': 'packages: {}\n',
        },
        rootPackage: 'a',
        outputs: {
          'a|inspectra/trivy/vulnerability.json': decodedMatches(
            contains('"findings": []'),
          ),
        },
      );

      expect(trivy.scannedLock, 'packages: {}\n');
    },
  );

  test('fails when Trivy itself fails', () async {
    final trivy = FakeTrivy(directory, exitCode: 2);

    final TestBuilderResult result = await testBuilder(
      secretScanBuilder(BuilderOptions.empty),
      {
        'a|pubspec.yaml': _pubspec(trivy.executable),
        'a|lib/a.dart': 'void main() {}',
      },
      rootPackage: 'a',
      outputs: {},
    );

    expect(result.succeeded, isFalse);
  });

  test('does nothing while Trivy is disabled', () async {
    await testBuilder(
      secretScanBuilder(BuilderOptions.empty),
      {'a|pubspec.yaml': 'name: a\n', 'a|lib/a.dart': 'void main() {}'},
      rootPackage: 'a',
      outputs: {},
    );
  });
}
