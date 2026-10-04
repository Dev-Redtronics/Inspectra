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

import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/severity.dart';

/// Summarises [findings] per severity, from critical to unknown, omitting
/// severities without findings.
///
/// Returns text such as `1 critical · 2 high`, or an empty string when there
/// are no findings.
String severityBreakdown(List<Finding> findings) {
  final parts = <String>[];
  for (final Severity severity in Severity.values) {
    final int count = findings.where((f) => f.severity == severity).length;
    if (count > 0) {
      parts.add('$count ${severity.name}');
    }
  }
  return parts.join(' · ');
}
