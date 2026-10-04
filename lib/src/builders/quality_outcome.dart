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

/// The result of a format or lint check run by `build_runner`.
final class QualityOutcome {
  /// Creates an outcome from the JSON [report], the [rendered] text and
  /// whether the check [failed] or merely [hasFindings].
  const QualityOutcome({
    required this.report,
    required this.rendered,
    required this.failed,
    required this.hasFindings,
  });

  /// The JSON report written to the build cache.
  final Map<String, Object?> report;

  /// The human readable result that is logged.
  final String rendered;

  /// Whether the check failed and fails the build.
  final bool failed;

  /// Whether the check reported findings, failing or not.
  final bool hasFindings;
}
