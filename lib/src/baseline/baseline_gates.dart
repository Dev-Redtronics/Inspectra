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

import 'package:inspectra/src/baseline/baseline_candidates.dart';
import 'package:inspectra/src/baseline/baseline_match.dart';
import 'package:inspectra/src/baseline/baseline_matcher.dart';
import 'package:inspectra/src/baseline/baseline_scope.dart';
import 'package:inspectra/src/quality/lint_issue.dart';
import 'package:inspectra/src/quality/lint_result.dart';
import 'package:inspectra/src/style/style_result.dart';
import 'package:inspectra/src/style/style_violation.dart';
import 'package:inspectra/src/trivy/finding.dart';

/// Applies the baseline of [matcher] to the style check [result].
///
/// Returns a result without the covered violations and with a baseline
/// summary, or [result] itself when the baseline is empty.
StyleResult baselineStyle(StyleResult result, BaselineMatcher matcher) {
  if (matcher.isEmpty) {
    return result;
  }
  final BaselineMatch<StyleViolation> match = matcher.partition(
    result.violations,
    styleCandidate,
    checked: (entry) => entry.scope == BaselineScope.style,
  );
  return StyleResult(
    checked: result.checked,
    rules: result.rules,
    violations: match.kept,
    failOnFindings: result.failOnFindings,
    baseline: matcher.summarize(match),
  );
}

/// Applies the baseline of [matcher] to the lint check [result].
///
/// Returns a result without the covered diagnostics and with a baseline
/// summary, or [result] itself when the baseline is empty.
LintResult baselineLint(LintResult result, BaselineMatcher matcher) {
  if (matcher.isEmpty) {
    return result;
  }
  final BaselineMatch<LintIssue> match = matcher.partition(
    result.issues,
    lintCandidate,
    checked: (entry) => entry.scope == BaselineScope.lint,
  );
  return LintResult(
    issues: match.kept,
    failOn: result.failOn,
    baseline: matcher.summarize(match),
  );
}

/// Applies the baseline of [matcher] to the configured Trivy scan
/// [results]; a skipped scan stays as it is.
///
/// Returns the results without the covered findings and with a baseline
/// summary each, or [results] themselves when the baseline is empty.
List<ScanResult> baselineScans(
  List<ScanResult> results,
  BaselineMatcher matcher,
) {
  if (matcher.isEmpty) {
    return results;
  }
  return <ScanResult>[
    for (final result in results) _baselineScan(result, matcher),
  ];
}

/// Applies the baseline of [matcher] to the result of one scan.
///
/// Returns the result without the covered findings, or [result] itself when
/// the scan was skipped.
ScanResult _baselineScan(ScanResult result, BaselineMatcher matcher) {
  if (result.skipped != null) {
    return result;
  }
  final BaselineMatch<ScanFinding> match = matcher.partition(
    result.findings,
    (finding) => scanCandidate(result.scan, finding),
    checked: (entry) =>
        entry.scope == BaselineScope.trivy && entry.source == result.scan,
  );
  return ScanResult(
    scan: result.scan,
    findings: match.kept,
    failOnFindings: result.failOnFindings,
    baseline: matcher.summarize(match),
  );
}
