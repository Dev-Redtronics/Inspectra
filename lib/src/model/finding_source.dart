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

/// The scanner or data source that produced a finding.
///
/// The source is part of every finding's fingerprint and is shown in reports
/// so that a reader can tell a known CVE from OSV.dev apart from a heuristic
/// match of the regex scanner.
enum FindingSource {
  /// The OSV.dev vulnerability database, queried by `audit` and `scan`.
  osv('osv'),

  /// The Trivy scanner, run by `trivy` and `scan`.
  trivy('trivy'),

  /// The regular expression rules of the source inspector.
  regex('regex'),

  /// The Shannon entropy scanner of the source inspector.
  entropy('entropy'),

  /// The invisible and confusable Unicode scanner of the source inspector.
  unicode('unicode'),

  /// The structural archive scanner of the source inspector.
  archive('archive'),

  /// The `pubspec.yaml` rule scanner.
  pubspec('pubspec'),

  /// The pub.dev trust assessment.
  trust('trust'),

  /// The typosquatting detector.
  typosquat('typosquat'),

  /// The dependency confusion detector.
  confusion('confusion'),

  /// The style check and its custom rules.
  style('style');

  /// Creates a source with its stable machine readable [id].
  const FindingSource(this.id);

  /// The stable identifier used in JSON and SARIF documents.
  final String id;
}
