@TestOn('posix')
library;

import 'dart:convert';

import 'package:inspectra/inspectra.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  late String root;
  late InspectraConfig defaults;

  setUp(() {
    root = temporaryDirectory();
    defaults = InspectraConfig.defaults('app');
  });

  group('scanSecrets', () {
    test('scans exactly the selected files under their own paths', () async {
      final trivy = FakeTrivy(
        root,
        report: {
          'Results': [
            {
              'Target': 'lib/config.dart',
              'Class': 'secret',
              'Secrets': [
                {
                  'RuleID': 'github-pat',
                  'Severity': 'CRITICAL',
                  'Title': 'GitHub Personal Access Token',
                  'StartLine': 3,
                },
              ],
            },
          ],
        },
      );

      final ScanResult result = await scanSecrets(
        trivy: Trivy(executable: trivy.executable, environment: const {}),
        config: defaults.trivy.secret,
        files: {
          'lib/config.dart': utf8.encode('const token = "...";'),
          'pubspec.yaml': utf8.encode('name: app'),
        },
        secretConfig: '/rules/trivy-secret.yaml',
      );

      expect(trivy.scannedFiles, ['lib/config.dart', 'pubspec.yaml']);
      expect(
        trivy.arguments,
        containsAllInOrder(['fs', '--scanners', 'secret']),
      );
      expect(
        trivy.arguments,
        containsAllInOrder(['--secret-config', '/rules/trivy-secret.yaml']),
      );
      expect(
        trivy.arguments,
        containsAllInOrder(['--severity', 'CRITICAL,HIGH,MEDIUM,LOW']),
      );
      expect(result.failed, isTrue);
      expect(result.findings.single.target, 'lib/config.dart');
      expect(result.findings.single.id, 'github-pat');
      expect(result.findings.single.detail, 'line 3');
      expect(
        result.render(),
        contains('[CRITICAL] lib/config.dart: github-pat'),
      );
    });

    test('is skipped when no file matches', () async {
      final ScanResult result = await scanSecrets(
        trivy: Trivy(),
        config: defaults.trivy.secret,
        files: const {},
      );

      expect(result.skipped, isNotNull);
      expect(result.failed, isFalse);
    });
  });

  group('scanLicenses', () {
    setUp(() {
      writeResolvedPackage(
        root,
        dependencies: ['http', 'copyleft', 'bare', 'local'],
        devDependencies: ['test'],
        packages: [
          const FakePackage('http', license: 'MIT'),
          const FakePackage('copyleft', license: 'GPL'),
          const FakePackage('custom', license: 'All rights reserved.'),
          const FakePackage('bare', dependencies: ['custom']),
          const FakePackage('local', source: 'path'),
          const FakePackage('test', license: 'GPL'),
        ],
      );
    });

    Map<String, Object?> licenseReport() => {
      'Results': [
        {
          'Target': 'Loose File License(s)',
          'Class': 'license-file',
          'Licenses': [
            {
              'Severity': 'LOW',
              'Category': 'notice',
              'FilePath': 'http/LICENSE',
              'Name': 'MIT',
            },
            {
              'Severity': 'CRITICAL',
              'Category': 'forbidden',
              'FilePath': 'copyleft/LICENSE',
              'Name': 'GPL-3.0',
            },
          ],
        },
      ],
    };

    test('reports forbidden, unclassified and missing licenses of shipped '
        'dependencies', () async {
      final trivy = FakeTrivy(p.join(root, 'app'), report: licenseReport());

      final ScanResult result = await scanLicenses(
        trivy: Trivy(executable: trivy.executable, environment: const {}),
        config: defaults.trivy.license,
        graph: await PackageGraph.load(p.join(root, 'app')),
      );

      expect(trivy.scannedFiles, [
        'copyleft/LICENSE',
        'custom/LICENSE',
        'http/LICENSE',
      ]);
      expect(trivy.arguments, contains('--license-full'));
      expect(
        result.findings.map(
          (finding) =>
              '${finding.severity.name} ${finding.target} ${finding.id}',
        ),
        [
          'critical copyleft 1.0.0 GPL-3.0',
          'unknown bare 1.0.0 no-license-file',
          'unknown custom 1.0.0 unclassified',
        ],
      );
      expect(result.failed, isTrue);
    });

    test('honours ignored licenses, ignored packages and severities', () async {
      final trivy = FakeTrivy(p.join(root, 'app'), report: licenseReport());
      final LicenseScanConfig config = InspectraConfig.parse({
        'trivy': {
          'license': {
            'severity': ['CRITICAL', 'LOW'],
            'ignored_licenses': ['gpl-3.0'],
            'ignored_packages': ['custom'],
          },
        },
      }, packageName: 'app').trivy.license;

      final ScanResult result = await scanLicenses(
        trivy: Trivy(executable: trivy.executable, environment: const {}),
        config: config,
        graph: await PackageGraph.load(p.join(root, 'app')),
      );

      expect(result.findings.map((finding) => finding.id), ['MIT']);
    });
  });

  group('scanVulnerabilities', () {
    final Map<String, List<Map<String, Object>>> report = {
      'Results': [
        {
          'Target': 'pubspec.lock',
          'Class': 'lang-pkgs',
          'Vulnerabilities': [
            {
              'VulnerabilityID': 'CVE-2020-35669',
              'VendorIDs': ['GHSA-4rgh-jx4f-qfcq'],
              'PkgName': 'http',
              'InstalledVersion': '0.13.0',
              'FixedVersion': '0.13.3',
              'Severity': 'MEDIUM',
              'Title': 'http before 0.13.3 vulnerable to header injection',
            },
          ],
        },
      ],
    };

    test('scans the lock file as is, dev dependencies included', () async {
      final trivy = FakeTrivy(root, report: report);

      final ScanResult result = await scanVulnerabilities(
        trivy: Trivy(executable: trivy.executable, environment: const {}),
        config: defaults.trivy.vulnerability,
        lockContent: 'packages: {}\n',
      );

      expect(trivy.scannedLock, 'packages: {}\n');
      expect(result.findings.single.target, 'http 0.13.0');
      expect(result.findings.single.detail, 'fixed in 0.13.3');
      expect(result.failed, isTrue);
    });

    test('narrows the lock file to shipped dependencies on request', () async {
      writeResolvedPackage(
        root,
        dependencies: ['http'],
        devDependencies: ['test'],
        packages: [const FakePackage('http'), const FakePackage('test')],
      );
      final trivy = FakeTrivy(root);
      final VulnerabilityScanConfig config = InspectraConfig.parse({
        'trivy': {
          'vulnerability': {
            'include_dev_dependencies': false,
            'ignore_unfixed': true,
          },
        },
      }, packageName: 'app').trivy.vulnerability;
      final PackageGraph graph = await PackageGraph.load(p.join(root, 'app'));

      await scanVulnerabilities(
        trivy: Trivy(executable: trivy.executable, environment: const {}),
        config: config,
        lockContent: '',
        graph: graph,
      );

      expect(PubspecLock.parse(trivy.scannedLock).packages.keys, ['http']);
      expect(trivy.arguments, contains('--ignore-unfixed'));
    });

    test('drops ignored vulnerabilities by CVE or GHSA identifier', () async {
      final trivy = FakeTrivy(root, report: report);
      final VulnerabilityScanConfig config = InspectraConfig.parse({
        'trivy': {
          'vulnerability': {
            'ignored_vulnerabilities': ['ghsa-4rgh-jx4f-qfcq'],
          },
        },
      }, packageName: 'app').trivy.vulnerability;

      final ScanResult result = await scanVulnerabilities(
        trivy: Trivy(executable: trivy.executable, environment: const {}),
        config: config,
        lockContent: 'packages: {}\n',
      );

      expect(result.findings, isEmpty);
    });

    test('does not fail on findings when told not to', () async {
      final trivy = FakeTrivy(root, report: report);
      final VulnerabilityScanConfig config = InspectraConfig.parse({
        'trivy': {
          'vulnerability': {'fail_on_findings': false},
        },
      }, packageName: 'app').trivy.vulnerability;

      final ScanResult result = await scanVulnerabilities(
        trivy: Trivy(executable: trivy.executable, environment: const {}),
        config: config,
        lockContent: 'packages: {}\n',
      );

      expect(result.findings, hasLength(1));
      expect(result.failed, isFalse);
    });
  });

  group('Trivy', () {
    test(
      'treats a non-zero exit as a failure of Trivy, not a finding',
      () async {
        final trivy = FakeTrivy(root, exitCode: 1);

        await expectLater(
          Trivy(
            executable: trivy.executable,
            environment: const {},
          ).scanFilesystem(
            target: root,
            scanners: const ['vuln'],
            severity: const [Severity.high],
          ),
          throwsA(
            isA<TrivyException>().having(
              (error) => error.message,
              'message',
              contains('exited with 1'),
            ),
          ),
        );
      },
    );

    test('explains a missing executable', () async {
      await expectLater(
        Trivy(
          executable: p.join(root, 'missing'),
          environment: const {},
        ).scanFilesystem(
          target: root,
          scanners: const ['vuln'],
          severity: const [Severity.high],
        ),
        throwsA(
          isA<TrivyException>().having(
            (error) => error.message,
            'message',
            contains(trivyExecutableVariable),
          ),
        ),
      );
    });

    test('lets the environment override the configured executable', () {
      expect(
        Trivy(
          executable: 'configured',
          environment: {trivyExecutableVariable: '/ci/trivy'},
        ).executable,
        '/ci/trivy',
      );
      expect(
        Trivy(executable: 'configured', environment: const {}).executable,
        'configured',
      );
      expect(Trivy(environment: const {}).executable, 'trivy');
    });
  });

  group('collectFiles', () {
    test('applies the include and exclude globs', () {
      writeFile(root, 'lib/a.dart', 'a');
      writeFile(root, 'pubspec.yaml', 'name: app');
      writeFile(root, 'README.md', 'readme');
      writeFile(root, 'build/generated.dart', 'generated');
      writeFile(root, '.dart_tool/cache.json', '{}');
      writeFile(root, 'packages/sub/build/x.yaml', 'x');

      final Map<String, List<int>> files = collectFiles(
        root,
        SecretScanConfig.defaultInclude,
        SecretScanConfig.defaultExclude,
      );

      expect(files.keys, ['lib/a.dart', 'pubspec.yaml']);
    });
  });

  group('resolveSecretConfig', () {
    test('uses trivy-secret.yaml only when it exists', () {
      expect(resolveSecretConfig(root, null), isNull);

      writeFile(root, 'trivy-secret.yaml', 'rules: []');

      expect(
        resolveSecretConfig(root, null),
        p.join(root, 'trivy-secret.yaml'),
      );
    });

    test('requires an explicitly configured file to exist', () {
      expect(
        () => resolveSecretConfig(root, 'missing.yaml'),
        throwsA(isA<InspectraConfigException>()),
      );
    });
  });
}
