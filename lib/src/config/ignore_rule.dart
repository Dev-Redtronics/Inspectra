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

import 'package:inspectra/src/config/config_suggestion.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/config/yaml_reader.dart';
import 'package:inspectra/src/model/finding.dart';

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

  /// Parses one entry of the `ignore:` list at [path].
  ///
  /// Returns the rule.
  ///
  /// Throws an [InspectraConfigException] for malformed entries.
  factory IgnoreRule._fromEntry(Object? entry, String path) {
    if (entry is! Map) {
      throw InspectraConfigException(
        path,
        'expected a mapping with id and '
        'reason.',
      );
    }
    const allowed = <String>{'id', 'reason', 'package', 'expires'};
    final Iterable<dynamic> unknown = entry.keys.where(
      (key) => !allowed.contains('$key'),
    );
    if (unknown.isNotEmpty) {
      throw InspectraConfigException(
        '$path.${unknown.first}',
        'unknown option.${didYouMean('${unknown.first}', allowed)} Known '
            'options here: id, package, reason, expires.',
      );
    }
    final String? id = _text(entry['id']);
    final String? reason = _text(entry['reason']);
    if (id == null || reason == null) {
      throw InspectraConfigException(
        path,
        'requires both "id" and '
        '"reason"; every suppression must be justified.',
      );
    }
    final String? expiresText = _text(entry['expires']);
    final DateTime? expires = expiresText == null
        ? null
        : DateTime.tryParse(expiresText);
    if (expiresText != null && expires == null) {
      throw InspectraConfigException(
        '$path.expires',
        'expected a date in the form YYYY-MM-DD, got "$expiresText".',
      );
    }
    return IgnoreRule(
      id: id,
      reason: reason,
      package: _text(entry['package']),
      expires: expires,
    );
  }

  /// Reads the `ignore:` list of the configuration in [yaml]; only the
  /// configuration file can express it.
  ///
  /// Returns the rules, empty when the list is absent.
  ///
  /// Throws an [InspectraConfigException] for malformed entries, entries
  /// without `id` or `reason`, unknown keys and invalid expiry dates.
  static List<IgnoreRule> listFromYaml(YamlReader yaml) {
    final Object? raw = yaml.structured('ignore', fallback: const <Object?>[]);
    if (raw == null) {
      return const <IgnoreRule>[];
    }
    final path = yaml.path.isEmpty ? 'ignore' : '${yaml.path}.ignore';
    if (raw is! List) {
      throw InspectraConfigException(
        path,
        'expected a list of entries with id and reason.',
      );
    }
    return <IgnoreRule>[
      for (var index = 0; index < raw.length; index++)
        IgnoreRule._fromEntry(raw[index], '$path[$index]'),
    ];
  }

  /// Returns [value] as trimmed text, or `null` when absent or blank.
  static String? _text(Object? value) {
    if (value == null) {
      return null;
    }
    final String text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

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
    final DateTime? lastDay = expires;
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
    final String? scope = package;
    return scope == null || scope == finding.packageName;
  }
}
