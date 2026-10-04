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

import 'package:pub_semver/pub_semver.dart';

import 'osv_affected.dart';

/// Determines the version that fixes a vulnerability for an installed
/// version.
///
/// A naive "first `fixed` event" answer is wrong for advisories with several
/// ranges, for example one for the 1.x and one for the 2.x line. This resolver
/// finds the range that actually contains the installed version and returns
/// its fix. When no range contains it, the smallest fix above the installed
/// version is returned.
final class FixedVersionResolver {
  /// Creates a resolver.
  const FixedVersionResolver();

  /// Resolves the fix for [installed] of [packageName] from [affected].
  ///
  /// Returns the fixing version, or `null` when no fix is published or the
  /// containing range ends with `last_affected`.
  String? resolve(
    List<OsvAffected> affected,
    String packageName,
    String installed,
  ) {
    final relevant = affected.where(
      (entry) => entry.packageName == packageName,
    );
    final ranges = relevant.expand((entry) => entry.ranges);
    final semverRanges = ranges.where((range) => range.type != 'GIT').toList();
    final version = _tryParse(installed);
    if (version == null) {
      return _firstFix(semverRanges.expand((range) => range.events));
    }
    for (final range in semverRanges) {
      final (contains, fix) = _match(range.events, version);
      if (contains) {
        return fix;
      }
    }
    return _smallestFixAbove(semverRanges.expand((r) => r.events), version);
  }

  /// Walks the [events] of one range and checks whether [version] lies in
  /// one of its intervals.
  ///
  /// Returns whether it does and, if so, the fix closing that interval.
  (bool, String?) _match(List<Map<String, String>> events, Version version) {
    Version? start;
    for (final event in events) {
      final introduced = event['introduced'];
      if (introduced != null) {
        start = introduced == '0' ? Version.none : _tryParse(introduced);
        continue;
      }
      final lower = start;
      if (lower == null) {
        continue;
      }
      final fixed = event['fixed'];
      final fixedVersion = fixed == null ? null : _tryParse(fixed);
      if (fixedVersion != null && version >= lower && version < fixedVersion) {
        return (true, fixed);
      }
      final lastAffected = event['last_affected'];
      final lastVersion = lastAffected == null ? null : _tryParse(lastAffected);
      if (lastVersion != null && version >= lower && version <= lastVersion) {
        return (true, null);
      }
      start = null;
    }
    final openEnded = start != null && version >= start;
    return (openEnded, null);
  }

  /// Finds the smallest `fixed` event above [version].
  ///
  /// Returns the fix, or `null` when there is none.
  String? _smallestFixAbove(
    Iterable<Map<String, String>> events,
    Version version,
  ) {
    final fixes =
        events
            .map((event) => event['fixed'])
            .nonNulls
            .map((fixed) => (fixed, _tryParse(fixed)))
            .where((pair) => pair.$2 != null && pair.$2! > version)
            .toList()
          ..sort((a, b) => a.$2!.compareTo(b.$2!));
    return fixes.firstOrNull?.$1;
  }

  /// Returns the first `fixed` event, used when versions cannot be parsed.
  String? _firstFix(Iterable<Map<String, String>> events) =>
      events.map((event) => event['fixed']).nonNulls.firstOrNull;

  /// Parses [text] as a semantic version.
  ///
  /// Returns the version, or `null` when [text] is not one.
  Version? _tryParse(String text) {
    try {
      return Version.parse(text);
    } on FormatException {
      return null;
    }
  }
}
