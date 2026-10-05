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

import 'package:inspectra/src/baseline/baseline.dart';
import 'package:inspectra/src/baseline/baseline_candidate.dart';
import 'package:inspectra/src/baseline/baseline_entry.dart';
import 'package:inspectra/src/baseline/baseline_match.dart';
import 'package:inspectra/src/baseline/baseline_summary.dart';
import 'package:inspectra/src/config/baseline_config.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:path/path.dart' as p;

/// Decides which current findings a baseline covers.
///
/// The findings of one key are covered up to the recorded count, in the
/// order of their lines; the rest are new. Findings more severe than
/// `baseline.max_severity` are never covered.
final class BaselineMatcher {
  /// Creates a matcher of [baseline] with the settings [config].
  const BaselineMatcher({required this.baseline, required this.config});

  /// Loads the baseline of the package in [packageRoot] as [config] names
  /// it.
  ///
  /// Returns a matcher, which covers nothing when the baseline is disabled
  /// or its file does not exist.
  ///
  /// Throws an `InvalidInputException` when the baseline file is malformed.
  factory BaselineMatcher.load(BaselineConfig config, String packageRoot) {
    if (!config.enabled) {
      return BaselineMatcher(
        baseline: Baseline(const <BaselineEntry>[]),
        config: config,
      );
    }
    final String path = p.normalize(p.join(packageRoot, config.file));
    return BaselineMatcher(baseline: Baseline.load(path), config: config);
  }

  /// The recorded findings.
  final Baseline baseline;

  /// The baseline settings.
  final BaselineConfig config;

  /// Whether the matcher covers nothing.
  bool get isEmpty => baseline.isEmpty;

  /// Splits [items] into new and covered findings; [describe] turns an item
  /// into its baseline candidate.
  ///
  /// [checked] selects the entries whose findings [items] are complete
  /// for: their recorded findings that no longer occur are counted as
  /// stale. Without it, nothing is stale, because the items are only a part
  /// of a scope, as for `audit`.
  ///
  /// Returns the match.
  BaselineMatch<T> partition<T>(
    List<T> items,
    BaselineCandidate Function(T item) describe, {
    bool Function(BaselineEntry entry)? checked,
  }) {
    final List<BaselineCandidate> candidates = items.map(describe).toList();
    final groups = <String, List<int>>{};
    for (var index = 0; index < candidates.length; index++) {
      groups.putIfAbsent(candidates[index].key, () => <int>[]).add(index);
    }
    final budget = <String, int>{
      for (final entry in baseline.entries) entry.key: entry.count,
    };
    final covered = <int>{};
    for (final MapEntry<String, List<int>> group in groups.entries) {
      final int allowed = budget[group.key] ?? 0;
      final List<int> eligible =
          group.value
              .where((index) => _coverable(candidates[index].severity))
              .toList()
            ..sort((a, b) {
              final int byLine = (candidates[a].line ?? 0).compareTo(
                candidates[b].line ?? 0,
              );
              return byLine != 0 ? byLine : a.compareTo(b);
            });
      covered.addAll(eligible.take(allowed));
    }
    final Iterable<BaselineEntry> stale = checked == null
        ? const <BaselineEntry>[]
        : baseline.entries.where(checked);
    final int staleCount = stale.fold(0, (sum, entry) {
      final int occurring = groups[entry.key]?.length ?? 0;
      final int missing = entry.count - occurring;
      return sum + (missing > 0 ? missing : 0);
    });
    return BaselineMatch<T>(
      kept: <T>[
        for (var index = 0; index < items.length; index++)
          if (!covered.contains(index)) items[index],
      ],
      baselined: <T>[
        for (var index = 0; index < items.length; index++)
          if (covered.contains(index)) items[index],
      ],
      stale: staleCount,
    );
  }

  /// Summarises [match] for a check result.
  ///
  /// Returns the summary.
  BaselineSummary summarize<T>(BaselineMatch<T> match) => BaselineSummary(
    covered: match.baselined.length,
    stale: match.stale,
    failOnStale: config.failOnStale,
  );

  /// Returns whether a finding of [severity] may be covered at all.
  bool _coverable(Severity severity) {
    final Severity? limit = config.maxSeverity;
    return limit == null || severity.rank >= limit.rank;
  }
}
