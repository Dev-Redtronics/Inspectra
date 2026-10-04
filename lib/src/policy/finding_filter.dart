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

import 'package:inspectra/src/config/ignore_rule.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/policy/filter_outcome.dart';

/// Applies the reporting policy to raw findings.
///
/// A finding is dropped when its severity is below [minSeverity] or when an
/// active ignore rule matches it. Ignore rules come from the configuration
/// file (with reason and expiry) and from repeated `--ignore` flags, which
/// match an id or alias for every package.
final class FindingFilter {
  /// Creates a filter evaluated at time [now].
  const FindingFilter({
    required this.minSeverity,
    required this.rules,
    required this.cliIgnores,
    required this.now,
  });

  /// Findings below this severity are dropped.
  final Severity minSeverity;

  /// The configured ignore rules.
  final List<IgnoreRule> rules;

  /// Identifiers given with `--ignore`.
  final List<String> cliIgnores;

  /// The time against which rule expiry is evaluated.
  final DateTime now;

  /// Filters [findings].
  ///
  /// Returns the kept and suppressed findings plus expired rules.
  FilterOutcome apply(List<Finding> findings) {
    final List<IgnoreRule> active = rules
        .where((rule) => !rule.isExpired(now))
        .toList();
    final List<IgnoreRule> expired = rules
        .where((rule) => rule.isExpired(now))
        .toList();
    final kept = <Finding>[];
    final suppressed = <Finding>[];
    for (final finding in findings) {
      if (!finding.severity.isAtLeast(minSeverity)) {
        continue;
      }
      final bool ignoredByFlag = cliIgnores.any(finding.identifiers.contains);
      final bool ignoredByRule = active.any((rule) => rule.matches(finding));
      if (ignoredByFlag || ignoredByRule) {
        suppressed.add(finding);
        continue;
      }
      kept.add(finding);
    }
    return FilterOutcome(
      kept: kept,
      suppressed: suppressed,
      expiredRules: expired,
    );
  }
}
