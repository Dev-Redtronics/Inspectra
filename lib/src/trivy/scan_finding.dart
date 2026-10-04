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

import 'package:inspectra/src/model/severity.dart';

/// One issue a scan reported.
class ScanFinding {
  /// Creates a finding.
  const ScanFinding({
    required this.severity,
    required this.target,
    required this.id,
    required this.title,
    this.detail,
  });

  /// How severe the issue is.
  final Severity severity;

  /// Where the issue was found: a file, or a package with its version.
  final String target;

  /// The rule, vulnerability or license identifier.
  final String id;

  /// A one-line description.
  final String title;

  /// Further information, such as the fixed version or a line number.
  final String? detail;

  /// Serializes this finding for the JSON report.
  Map<String, Object?> toJson() => {
    'severity': severity.trivyName,
    'target': target,
    'id': id,
    'title': title,
    if (detail != null) 'detail': detail,
  };
}
