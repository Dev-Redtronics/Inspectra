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

/// The evaluations of `inspectra report`, in the order of the report.
enum ReportStep {
  /// The size of the code base and its dependencies.
  codebase('codebase', 'Codebase'),

  /// The supply-chain scan: OSV.dev, typosquatting, dependency confusion
  /// and the Trivy filesystem scan.
  scan('scan', 'Supply chain'),

  /// The pubspec rules and the dependency policy.
  deps('deps', 'Dependencies'),

  /// The risky settings of the configuration.
  config('config', 'Configuration'),

  /// The format check.
  format('format', 'Format'),

  /// The lint check.
  lint('lint', 'Lint'),

  /// The style check.
  style('style', 'Style'),

  /// The public API check.
  api('api', 'Public API'),

  /// The comparison of the public API with the last release.
  semver('semver', 'Semantic versioning'),

  /// The changelog check.
  changelog('changelog', 'Changelog'),

  /// The configured Trivy scans.
  trivy('trivy', 'Trivy'),

  /// The coverage gate.
  coverage('coverage', 'Coverage');

  /// Creates the step [id] titled [title].
  const ReportStep(this.id, this.title);

  /// The name accepted by `--skip`, also the id of its section.
  final String id;

  /// The title of its section.
  final String title;

  /// Finds the step named [id].
  ///
  /// Returns the step, or `null` when [id] names none.
  static ReportStep? tryParse(String id) =>
      values.where((step) => step.id == id).firstOrNull;
}
