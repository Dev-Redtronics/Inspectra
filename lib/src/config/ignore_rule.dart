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

/// A documented decision to suppress a finding.
///
/// Configured in the `ignore:` list of `inspectra.yaml`:
///
/// ```yaml
/// ignore:
///   - id: GHSA-xxxx-yyyy-zzzz
///     package: http
///     reason: Not reachable, we never parse untrusted multipart bodies.
///     expires: 2027-01-31
/// ```
///
/// A reason is mandatory so that every suppression is auditable. Once
/// [expires] has passed the rule stops matching and Inspectra warns, which
/// forces the decision to be revisited.
final class IgnoreRule {
  /// Creates a rule suppressing [id], optionally only for [package], until
  /// [expires].
  const IgnoreRule({
    required this.id,
    required this.reason,
    this.package,
    this.expires,
  });

  /// The rule id, advisory id or alias to suppress.
  final String id;

  /// Why the finding is acceptable.
  final String reason;

  /// Restricts the rule to findings of this package.
  final String? package;

  /// The last day on which the rule applies, or `null` for no expiry.
  final DateTime? expires;

  /// Whether the rule has expired at [now].
  ///
  /// The rule is valid through the whole day of [expires].
  ///
  /// Returns `true` once the day after [expires] has started.
  bool isExpired(DateTime now) {
    final lastDay = expires;
    if (lastDay == null) {
      return false;
    }
    final endOfDay = DateTime.utc(lastDay.year, lastDay.month, lastDay.day + 1);
    return !now.isBefore(endOfDay);
  }

  /// Whether this rule suppresses [finding].
  ///
  /// Returns `true` when [id] equals the finding's rule id or one of its
  /// aliases and, if [package] is set, the package matches too.
  bool matches(Finding finding) {
    if (!finding.identifiers.contains(id)) {
      return false;
    }
    final scope = package;
    return scope == null || scope == finding.packageName;
  }
}
