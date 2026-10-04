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
import 'package:inspectra/src/trivy/trivy_report_mapper.dart';
import 'package:inspectra/src/trivy/trivy_runner.dart';
import 'package:test/test.dart';

/// Tests the translation of Trivy reports and command lines.
void main() {
  test('maps every supported result section', () {
    final findings = const TrivyReportMapper(pathPrefix: 'app')
        .map(<String, Object?>{
          'Results': <Object?>[
            <String, Object?>{
              'Target': 'pubspec.lock',
              'Vulnerabilities': <Object?>[
                <String, Object?>{
                  'VulnerabilityID': 'CVE-2020-35669',
                  'PkgName': 'http',
                  'InstalledVersion': '0.13.0',
                  'FixedVersion': '0.13.3',
                  'Severity': 'MEDIUM',
                  'Title': 'header injection',
                  'PrimaryURL': 'https://avd.aquasec.com/nvd/cve-2020-35669',
                },
              ],
            },
            <String, Object?>{
              'Target': 'lib/keys.dart',
              'Secrets': <Object?>[
                <String, Object?>{
                  'RuleID': 'aws-access-key-id',
                  'Severity': 'CRITICAL',
                  'Title': 'AWS Access Key ID',
                  'StartLine': 3,
                  'Match': 'const key = "****";',
                },
              ],
              'Misconfigurations': <Object?>[
                <String, Object?>{'ID': 'DS002', 'Status': 'PASS'},
                <String, Object?>{
                  'ID': 'DS001',
                  'Status': 'FAIL',
                  'Severity': 'HIGH',
                  'Title': 'Root user',
                  'CauseMetadata': <String, Object?>{'StartLine': 7},
                },
              ],
              'Licenses': <Object?>[
                <String, Object?>{
                  'Name': 'GPL-3.0',
                  'Category': 'restricted',
                  'Severity': 'HIGH',
                  'PkgName': 'x',
                },
              ],
            },
          ],
        });
    expect(findings.map((f) => f.ruleId), <String>[
      'CVE-2020-35669',
      'aws-access-key-id',
      'DS001',
      'LICENSE:GPL-3.0',
    ]);
    expect(findings[0].fixedVersion, '0.13.3');
    expect(findings[0].location?.path, 'app/pubspec.lock');
    expect(findings[1].location?.line, 3);
    expect(findings[1].severity, Severity.critical);
    expect(findings[2].location?.line, 7);
    expect(findings[3].attributes['kind'], 'license');
  });

  test('builds the Trivy command line from the configuration', () {
    const runner = TrivyRunner(
      config: TrivyConfig(
        skipDbUpdate: true,
        dbRepository: 'registry.corp/trivy-db',
        extraArgs: <String>['--debug'],
      ),
      processRunner: SystemProcessRunner(),
    );
    final arguments = runner.arguments('/project');
    expect(arguments.first, 'fs');
    expect(arguments, containsAllInOrder(<String>['--exit-code', '0']));
    expect(
      arguments,
      containsAllInOrder(<String>['--scanners', 'vuln,secret,misconfig']),
    );
    expect(arguments, contains('--skip-db-update'));
    expect(
      arguments,
      containsAllInOrder(<String>['--db-repository', 'registry.corp/trivy-db']),
    );
    expect(arguments.sublist(arguments.length - 2), <String>[
      '--debug',
      '/project',
    ]);
  });
}
