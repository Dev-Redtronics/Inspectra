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

import 'dart:convert';

import 'package:inspectra/src/trivy/trivy.dart';

/// The parts of a Trivy JSON report Inspectra reads.
class TrivyReport {
  /// Creates a report from its results.
  const TrivyReport(this.results);

  /// Parses the output of `trivy --format json`.
  factory TrivyReport.parse(String json) {
    final Object? decoded = jsonDecode(json);
    final Object? results = decoded is Map ? decoded['Results'] : null;
    return TrivyReport([
      if (results is List)
        for (final result in results)
          if (result is Map<String, Object?>) TrivyResult(result),
    ]);
  }

  /// One entry per scanned target.
  final List<TrivyResult> results;
}
