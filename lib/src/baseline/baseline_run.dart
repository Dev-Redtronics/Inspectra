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
import 'package:inspectra/src/baseline/baseline_entry.dart';

/// The findings of one scope as `baseline create` and `baseline prune`
/// collected them.
final class BaselineRun {
  /// Creates the run that found [candidates] and is complete for the
  /// entries [covers] selects.
  const BaselineRun({required this.candidates, required this.covers});

  /// The current findings.
  final List<BaselineCandidate> candidates;

  /// Selects the recorded entries the run is complete for: their scope, but
  /// without the parts that did not run, such as a skipped Trivy scan.
  final bool Function(BaselineEntry entry) covers;
}
