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

import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/trust/trust_info.dart';

/// The raw outcome of inspecting one package version.
final class InspectionResult {
  /// Creates an inspection outcome.
  const InspectionResult({
    required this.package,
    required this.version,
    required this.entryCount,
    required this.dartFileCount,
    required this.findings,
    required this.trust,
  });

  /// The inspected package.
  final String package;

  /// The inspected version.
  final String version;

  /// The number of archive entries.
  final int entryCount;

  /// The number of Dart files.
  final int dartFileCount;

  /// Every finding of every scanner, including trust findings.
  final List<Finding> findings;

  /// The trust assessment of the inspected version.
  final TrustInfo trust;
}
