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

import 'package:inspectra/src/audit/audit_scan.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/trivy/trivy_outcome.dart';

/// The raw outcome of the `scan` command, before reporting policies.
final class ScanResult {
  /// Creates a scan outcome.
  const ScanResult({
    required this.root,
    required this.audits,
    required this.pubspecs,
    required this.findings,
    required this.trivy,
    required this.confusionChecked,
  });

  /// The display path of the scanned directory.
  final String root;

  /// One audit per lockfile.
  final List<AuditScan> audits;

  /// The display paths of the analysed pubspecs.
  final List<String> pubspecs;

  /// Every finding of every scanner, OSV and Trivy duplicates merged.
  final List<Finding> findings;

  /// The Trivy step.
  final TrivyOutcome trivy;

  /// Whether the network based dependency confusion check ran.
  final bool confusionChecked;
}
