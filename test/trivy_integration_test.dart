/// Runs the scans against the real Trivy binary.
///
/// Skipped when Trivy is not installed. The vulnerability test downloads the
/// Trivy database on its first run.
@Tags(['trivy'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:inspectra/inspectra.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

final bool _trivyInstalled = () {
  try {
    return Process.runSync(Trivy().executable, ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

void main() {
  final String? skip = _trivyInstalled ? null : 'Trivy is not installed.';
  final TrivyConfig defaults = InspectraConfig.defaults('app').trivy;

  test('finds a hard-coded GitHub token', () async {
    final ScanResult result = await scanSecrets(
      trivy: Trivy(workingDirectory: temporaryDirectory()),
      config: defaults.secret,
      files: {
        'lib/config.dart': utf8.encode(
          "const token = 'ghp_abcdefghijklmnopqrstuvwxyz0123456789';\n",
        ),
        'lib/clean.dart': utf8.encode('const greeting = "hello";\n'),
      },
    );

    expect(
      result.findings.map((finding) => '${finding.target} ${finding.id}'),
      ['lib/config.dart github-pat'],
    );
    expect(result.failed, isTrue);
  }, skip: skip);

  test('classifies license files', () async {
    final String root = temporaryDirectory();
    writeResolvedPackage(
      root,
      dependencies: ['permissive'],
      packages: [const FakePackage('permissive', license: _mitLicense)],
    );
    final LicenseScanConfig config = InspectraConfig.parse({
      'trivy': {
        'license': {
          'severity': ['LOW'],
        },
      },
    }, packageName: 'app').trivy.license;

    final ScanResult result = await scanLicenses(
      trivy: Trivy(workingDirectory: temporaryDirectory()),
      config: config,
      graph: await PackageGraph.load('$root/app'),
    );

    expect(result.findings.single.target, 'permissive 1.0.0');
    expect(result.findings.single.id, 'MIT');
  }, skip: skip);

  test(
    'finds a vulnerable pub package',
    () async {
      const lock = '''
packages:
  http:
    dependency: "direct main"
    description:
      name: http
      url: "https://pub.dev"
    source: hosted
    version: "0.13.0"
sdks:
  dart: ">=3.0.0 <4.0.0"
''';

      final ScanResult result = await scanVulnerabilities(
        trivy: Trivy(workingDirectory: temporaryDirectory()),
        config: defaults.vulnerability,
        lockContent: lock,
      );

      expect(
        result.findings.map((finding) => finding.id),
        contains('CVE-2020-35669'),
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

const _mitLicense = '''
MIT License

Copyright (c) 2026 Example

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';
