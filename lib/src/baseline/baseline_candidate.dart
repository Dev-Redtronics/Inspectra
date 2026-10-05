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

import 'package:inspectra/src/baseline/baseline_scope.dart';
import 'package:inspectra/src/model/severity.dart';

/// One current finding, described the way a baseline compares it.
///
/// Findings, lint diagnostics, style violations and Trivy scan findings all
/// become candidates, so that one matcher decides for every check whether a
/// finding is covered by the baseline.
final class BaselineCandidate {
  /// Creates a candidate; a [path] is stored with `/` as separator.
  BaselineCandidate({
    required this.scope,
    required this.source,
    required this.rule,
    required this.severity,
    required this.title,
    this.package,
    String? path,
    this.line,
  }) : path = path?.replaceAll(r'\', '/');

  /// The scope the finding belongs to.
  final BaselineScope scope;

  /// What reported the finding within its scope, for example `osv`, `style`
  /// or the name of a Trivy scan.
  final String source;

  /// The rule, advisory or diagnostic code.
  final String rule;

  /// How severe the finding is.
  final Severity severity;

  /// A one-line description, recorded for the people reading the baseline.
  final String title;

  /// The affected package, if any.
  final String? package;

  /// The affected file relative to the package root, if any.
  final String? path;

  /// The line of the finding, which orders findings of the same key but is
  /// not part of the key.
  final int? line;

  /// The identity of the finding in a baseline: scope, source, rule, package
  /// and path, deliberately without line number and package version, so that
  /// moving code or upgrading a dependency does not make a finding new.
  String get key => baselineKey(
    scope: scope,
    source: source,
    rule: rule,
    package: package,
    path: path,
  );
}

/// Joins the parts of a baseline key.
///
/// Returns the key shared by `BaselineCandidate` and `BaselineEntry`.
String baselineKey({
  required BaselineScope scope,
  required String source,
  required String rule,
  required String? package,
  required String? path,
}) => <String>[scope.id, source, rule, package ?? '', path ?? ''].join('|');
