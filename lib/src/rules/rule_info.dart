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

import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/severity.dart';

/// What one rule of Inspectra checks, for `inspectra explain` and the rule
/// reference.
final class RuleInfo {
  /// Creates the description of the rule [id] of [source], reported with
  /// [severity] by default: a one line [summary] and an [explanation] of
  /// why it matters and how to resolve it.
  const RuleInfo({
    required this.id,
    required this.source,
    required this.severity,
    required this.summary,
    required this.explanation,
  });

  /// The stable rule id, as findings carry it.
  final String id;

  /// The scanner that reports the rule.
  final FindingSource source;

  /// The severity the rule reports with by default.
  final Severity severity;

  /// What the rule reports, in one line.
  final String summary;

  /// Why it matters and how to resolve it.
  final String explanation;

  /// Serializes the rule for JSON output.
  ///
  /// Returns the JSON object.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'source': source.id,
    'severity': severity.name,
    'summary': summary,
    'explanation': explanation,
  };
}
