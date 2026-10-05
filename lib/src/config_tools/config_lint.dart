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

import 'package:inspectra/src/config/config_overrides.dart';
import 'package:inspectra/src/config/config_suggestion.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/config_tools/config_lint_collector.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/snippet_sanitizer.dart';

/// The `INSPECTRA_*` environment variables that name no option but are read
/// by Inspectra itself.
const inspectraVariables = <String>{
  'INSPECTRA_CONFIG',
  'INSPECTRA_TRIVY',
  'INSPECTRA_DEBUG',
  'INSPECTRA_CACHE_DIR',
};

/// The options that name a remote service, which must be reached over
/// HTTPS.
const _remoteOptions = <String>[
  'network.osv_url',
  'network.pub_hosted_url',
  'trivy.download_base_url',
  'trivy.latest_release_url',
];

/// Checks the effective configuration [config] for risky settings.
///
/// [recorder] holds where each value came from and locates findings in the
/// configuration file; [environment] are the environment variables and
/// [knownPaths] the options that can be overridden, which reveal
/// misspelled `INSPECTRA_*` variables. Ignore rules are judged at [now];
/// [baselineExists] tells whether the baseline file exists.
///
/// Returns the findings of the source [FindingSource.config].
List<Finding> lintConfig({
  required InspectraConfig config,
  required ConfigRecorder recorder,
  required Map<String, String> environment,
  required List<String> knownPaths,
  required DateTime now,
  required bool baselineExists,
}) {
  final lint = ConfigLintCollector(recorder);
  for (final String key in _remoteOptions) {
    final Object? value = recorder[key]?.value;
    if (value is String && value.toLowerCase().startsWith('http://')) {
      lint.add(
        key,
        'CONFIG_INSECURE_URL',
        Severity.high,
        '$key uses plain HTTP',
        'Advisories, package metadata and Trivy releases read from '
            '${SnippetSanitizer.sanitize(value)} can be changed by anyone on '
            'the network path. Use an https:// URL.',
      );
    }
  }
  _unknownVariables(lint, environment, knownPaths);
  _trivy(lint, config.trivy);
  _ignoreRules(lint, config.ignore, now);
  _gates(lint, config);
  if (config.minSeverity != Severity.unknown) {
    lint.add(
      'min_severity',
      'CONFIG_MIN_SEVERITY',
      Severity.low,
      'min_severity hides every finding below ${config.minSeverity.label}',
      'Hidden findings appear in no report, so nobody decides about them. '
          'Prefer fail_on to decide what fails, and ignore rules with a '
          'reason for what is accepted.',
    );
  }
  final bool noThreshold =
      config.coverage.enabled && config.coverage.minLineCoverage == null;
  if (noThreshold) {
    lint.add(
      'coverage.enabled',
      'CONFIG_NO_COVERAGE_THRESHOLD',
      Severity.low,
      'The coverage gate has no threshold',
      'Without coverage.min_line_coverage the gate only reports the '
          'coverage and never fails.',
    );
  }
  final bool unbounded =
      config.baseline.enabled &&
      baselineExists &&
      config.baseline.maxSeverity == null;
  if (unbounded) {
    lint.add(
      'baseline.file',
      'CONFIG_BASELINE_UNBOUNDED',
      Severity.low,
      'The baseline may cover findings of any severity',
      'Set baseline.max_severity, for example to high, so that a recorded '
          'CRITICAL finding still fails.',
    );
  }
  return lint.findings;
}

/// Reports `INSPECTRA_*` variables of [environment] that name no option of
/// [knownPaths].
void _unknownVariables(
  ConfigLintCollector lint,
  Map<String, String> environment,
  List<String> knownPaths,
) {
  final known = <String>{
    ...inspectraVariables,
    ...knownPaths.map(ConfigOverrides.environmentName),
  };
  final List<String> names =
      environment.keys
          .where((name) => name.toUpperCase().startsWith('INSPECTRA_'))
          .where((name) => !known.contains(name.toUpperCase()))
          .toList()
        ..sort();
  for (final name in names) {
    final String variable = SnippetSanitizer.sanitize(name);
    lint.add(
      null,
      'CONFIG_UNKNOWN_VARIABLE',
      Severity.medium,
      'The environment variable $variable names no option and is ignored',
      'Inspectra reads INSPECTRA_ followed by the upper case option path, '
          'such as INSPECTRA_TRIVY_VERSION for trivy.version.'
          '${didYouMean(name.toUpperCase(), known)}',
      variable: variable,
    );
  }
}

/// Reports a Trivy that never runs or is not pinned.
void _trivy(ConfigLintCollector lint, TrivyConfig trivy) {
  if (trivy.mode == TrivyMode.disabled) {
    lint.add(
      'trivy.mode',
      'CONFIG_TRIVY_DISABLED',
      Severity.medium,
      'Trivy never runs (trivy.mode: disabled)',
      'scan, trivy and check skip the secret, license, vulnerability and '
          'misconfiguration scans entirely.',
    );
  }
  if (trivy.version == TrivyConfig.latestVersion) {
    lint.add(
      'trivy.version',
      'CONFIG_UNPINNED_TRIVY',
      Severity.medium,
      'The Trivy version is not pinned (trivy.version: latest)',
      'Every run may use another Trivy release, so the same commit can pass '
          'today and fail tomorrow. Pin an exact version such as '
          '${TrivyConfig.pinnedVersion}.',
    );
  }
}

/// Reports expired ignore rules and rules without an expiry date.
void _ignoreRules(
  ConfigLintCollector lint,
  List<IgnoreRule> rules,
  DateTime now,
) {
  for (final rule in rules) {
    final String id = SnippetSanitizer.sanitize(rule.id);
    final DateTime? expires = rule.expires;
    if (expires == null) {
      lint.add(
        'ignore',
        'CONFIG_IGNORE_WITHOUT_EXPIRY',
        Severity.low,
        'The ignore rule for $id never expires',
        'Give it an expires date, so that the decision to accept the finding '
            'is revisited.',
        package: rule.package,
      );
      continue;
    }
    if (rule.isExpired(now)) {
      final String day = expires.toIso8601String().substring(0, 10);
      lint.add(
        'ignore',
        'CONFIG_IGNORE_EXPIRED',
        Severity.medium,
        'The ignore rule for $id expired on $day',
        'It no longer suppresses anything. Remove it, or renew it with a '
            'new reason and expiry date.',
        package: rule.package,
      );
    }
  }
}

/// Reports enabled checks that never fail.
void _gates(ConfigLintCollector lint, InspectraConfig config) {
  final TrivyConfig trivy = config.trivy;
  final gates = <(String, bool)>[
    ('format.fail_on_findings', config.format.enabled),
    ('style.fail_on_findings', config.style.enabled),
    ('trivy.secret.fail_on_findings', trivy.enabled && trivy.secret.enabled),
    ('trivy.license.fail_on_findings', trivy.enabled && trivy.license.enabled),
    (
      'trivy.vulnerability.fail_on_findings',
      trivy.enabled && trivy.vulnerability.enabled,
    ),
    (
      'trivy.filesystem.fail_on_findings',
      trivy.enabled && trivy.filesystem.enabled,
    ),
  ];
  for (final (key, enabled) in gates) {
    if (enabled && lint.valueOf(key) == false) {
      final String check = key.substring(0, key.lastIndexOf('.'));
      lint.add(
        key,
        'CONFIG_GATE_NOT_FAILING',
        Severity.low,
        'The $check check is enabled but never fails',
        'With $key: false its findings are only reported.',
      );
    }
  }
  if (config.lint.enabled && config.lint.failOn == LintLevel.none) {
    lint.add(
      'lint.fail_on',
      'CONFIG_GATE_NOT_FAILING',
      Severity.low,
      'The lint check is enabled but never fails',
      'With lint.fail_on: none its diagnostics are only reported.',
    );
  }
}
