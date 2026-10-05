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

import 'package:inspectra/src/baseline/baseline_candidate.dart';
import 'package:inspectra/src/baseline/baseline_scope.dart';
import 'package:inspectra/src/config/lint_level.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/quality/lint_issue.dart';
import 'package:inspectra/src/style/style_violation.dart';
import 'package:inspectra/src/trivy/scan_finding.dart';
import 'package:pub_semver/pub_semver.dart';

/// The source of every lint candidate.
const lintSource = 'analyzer';

/// The source of every style candidate.
const styleSource = 'style';

/// A Trivy target of the form `<package> <version>`.
final _packageTarget = RegExp(r'^([a-z0-9_]+) (\S+)$');

/// Describes a supply-chain [finding] of `scan`, `audit`, `typosquat` or
/// `trivy` for the baseline.
///
/// Returns the candidate of the `scan` scope; the package version is left
/// out.
BaselineCandidate findingCandidate(Finding finding) => BaselineCandidate(
  scope: BaselineScope.scan,
  source: finding.source.id,
  rule: finding.ruleId,
  severity: finding.severity,
  title: finding.title,
  package: finding.packageName,
  path: finding.location?.path,
  line: finding.location?.line,
);

/// Describes a lint [issue] for the baseline: errors count as high,
/// warnings as medium and infos as low.
///
/// Returns the candidate of the `lint` scope.
BaselineCandidate lintCandidate(LintIssue issue) => BaselineCandidate(
  scope: BaselineScope.lint,
  source: lintSource,
  rule: issue.code,
  severity: switch (issue.severity) {
    LintLevel.error => Severity.high,
    LintLevel.warning => Severity.medium,
    LintLevel.info => Severity.low,
    LintLevel.none => Severity.unknown,
  },
  title: issue.message,
  path: issue.path,
  line: issue.line,
);

/// Describes a style [violation] for the baseline.
///
/// Returns the candidate of the `style` scope.
BaselineCandidate styleCandidate(StyleViolation violation) => BaselineCandidate(
  scope: BaselineScope.style,
  source: styleSource,
  rule: violation.ruleId,
  severity: Severity.low,
  title: violation.message,
  path: violation.path,
  line: violation.line,
);

/// Describes a [finding] of the configured Trivy [scan] for the baseline.
///
/// A target of the form `<package> <version>` becomes the package without
/// its version; any other target is the path.
///
/// Returns the candidate of the `trivy` scope.
BaselineCandidate scanCandidate(String scan, ScanFinding finding) {
  final RegExpMatch? match = _packageTarget.firstMatch(finding.target);
  final String? version = match?.group(2);
  final bool isPackage = version != null && _isVersion(version);
  return BaselineCandidate(
    scope: BaselineScope.trivy,
    source: scan,
    rule: finding.id,
    severity: finding.severity,
    title: finding.title,
    package: isPackage ? match?.group(1) : null,
    path: isPackage ? null : finding.target,
  );
}

/// Returns whether [text] is a semantic version.
bool _isVersion(String text) {
  try {
    Version.parse(text);
    return true;
  } on FormatException {
    return false;
  }
}
