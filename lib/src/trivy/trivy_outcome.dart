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

import '../model/finding.dart';
import 'trivy_provision.dart';

/// The result of the Trivy step of a scan.
final class TrivyOutcome {
  /// Creates an outcome from the [provision] and, when Trivy ran, its
  /// [findings].
  const TrivyOutcome({required this.provision, required this.findings});

  /// How Trivy was made available, or why it was not.
  final TrivyProvision provision;

  /// The raw findings reported by Trivy; empty when it did not run.
  final List<Finding> findings;

  /// Whether Trivy actually ran.
  bool get ran => provision is TrivyAvailable;

  /// Serialises the provision state for reports.
  ///
  /// Returns the JSON object.
  Map<String, Object?> toJson() {
    final current = provision;
    return switch (current) {
      TrivyAvailable() => <String, Object?>{
        'status': 'ran',
        'executable': current.executable,
        'version': current.version,
        'origin': current.origin.id,
      },
      TrivyUnavailable() => <String, Object?>{
        'status': 'skipped',
        'reason': current.reason,
      },
    };
  }
}
