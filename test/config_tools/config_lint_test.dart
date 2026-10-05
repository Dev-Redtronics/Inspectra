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
import 'package:inspectra/src/config_tools/config_lint.dart';
import 'package:test/test.dart';

/// Tests the checks of `config lint`.
void main() {
  /// Lints the `inspectra.yaml` [text] with the [environment] and the
  /// command line overrides [cli], judged at [now].
  ///
  /// Returns the findings.
  List<Finding> lint(
    String text, {
    Map<String, String> environment = const <String, String>{},
    Map<String, String> cli = const <String, String>{},
    DateTime? now,
    bool baselineExists = false,
  }) {
    final recorder = ConfigRecorder();
    final overrides = ConfigOverrides(
      cli: cli,
      environment: Environment(environment),
    );
    final config = InspectraConfig.fromSources(
      pubspec: 'name: demo\n',
      configFile: text,
      overrides: overrides,
      recorder: recorder,
    );
    return lintConfig(
      config: config,
      recorder: recorder,
      environment: environment,
      knownPaths: overrides.knownPaths,
      now: now ?? DateTime.utc(2026, 10),
      baselineExists: baselineExists,
    );
  }

  /// Returns the rule ids of [findings].
  List<String> rules(List<Finding> findings) =>
      findings.map((finding) => finding.ruleId).toList();

  test('the defaults have no risky settings', () {
    expect(lint(''), isEmpty);
  });

  test('plain HTTP services are reported at their line', () {
    final List<Finding> findings = lint(
      'network:\n  osv_url: http://osv.corp\n'
      'trivy:\n  download_base_url: HTTP://mirror.corp/trivy\n',
    );
    expect(rules(findings), <String>[
      'CONFIG_INSECURE_URL',
      'CONFIG_INSECURE_URL',
    ]);
    final Finding first = findings.first;
    expect(first.source, FindingSource.config);
    expect(first.severity, Severity.high);
    expect(first.location.toString(), 'inspectra.yaml:2');
    expect(first.attributes['option'], 'network.osv_url');
  });

  test('a misspelled INSPECTRA_ variable is reported with a suggestion', () {
    final List<Finding> findings = lint(
      '',
      environment: <String, String>{
        'INSPECTRA_TRIVY_VERSON': '0.70.0',
        'INSPECTRA_TRIVY_VERSION': '0.70.0',
        'INSPECTRA_CACHE_DIR': '/tmp/cache',
        'INSPECTRA_TRIVY': '/opt/trivy',
        'HOME': '/home/me',
      },
    );
    final Finding finding = findings.single;
    expect(finding.ruleId, 'CONFIG_UNKNOWN_VARIABLE');
    expect(finding.title, contains('INSPECTRA_TRIVY_VERSON'));
    expect(finding.description, contains('"INSPECTRA_TRIVY_VERSION"'));
    expect(finding.location, isNull);
    expect(finding.attributes['variable'], 'INSPECTRA_TRIVY_VERSON');
  });

  test('a disabled or unpinned Trivy is reported', () {
    expect(
      rules(lint('trivy:\n  mode: disabled\n  version: latest\n')),
      <String>['CONFIG_TRIVY_DISABLED', 'CONFIG_UNPINNED_TRIVY'],
    );
    final Finding environment = lint(
      '',
      environment: <String, String>{'INSPECTRA_TRIVY_MODE': 'disabled'},
    ).single;
    expect(environment.location, isNull);
    expect(environment.attributes['variable'], 'INSPECTRA_TRIVY_MODE');
  });

  test('ignore rules without expiry or past it are reported', () {
    final List<Finding> findings = lint(
      'ignore:\n'
      '  - id: GHSA-1\n    reason: Not reachable.\n'
      '  - id: GHSA-2\n    reason: Not reachable.\n    expires: 2026-01-31\n'
      '  - id: GHSA-3\n    reason: Not reachable.\n    expires: 2027-01-31\n'
      '    package: http\n',
    );
    expect(rules(findings), <String>[
      'CONFIG_IGNORE_WITHOUT_EXPIRY',
      'CONFIG_IGNORE_EXPIRED',
    ]);
    expect(findings.last.title, contains('expired on 2026-01-31'));
    expect(findings.first.location.toString(), 'inspectra.yaml:1');
  });

  test('enabled checks that never fail are reported', () {
    final List<Finding> findings = lint(
      'format:\n  enabled: true\n  fail_on_findings: false\n'
      'style:\n  fail_on_findings: false\n'
      'lint:\n  enabled: true\n  fail_on: none\n'
      'trivy:\n  enabled: true\n  license:\n    fail_on_findings: false\n',
    );
    expect(findings.map((f) => f.attributes['option']), <String>[
      'format.fail_on_findings',
      'trivy.license.fail_on_findings',
      'lint.fail_on',
    ]);
    expect(rules(findings).toSet(), <String>{'CONFIG_GATE_NOT_FAILING'});
  });

  test('hidden findings, a gate without threshold and an open baseline', () {
    expect(
      rules(
        lint(
          'min_severity: high\ncoverage:\n  enabled: true\n',
          baselineExists: true,
        ),
      ),
      <String>[
        'CONFIG_MIN_SEVERITY',
        'CONFIG_NO_COVERAGE_THRESHOLD',
        'CONFIG_BASELINE_UNBOUNDED',
      ],
    );
    expect(
      lint(
        'coverage:\n  enabled: true\n  min_line_coverage: 80\n'
        'baseline:\n  max_severity: high\n',
        baselineExists: true,
      ),
      isEmpty,
    );
    expect(lint('', baselineExists: true), hasLength(1));
  });
}
