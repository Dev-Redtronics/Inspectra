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

/// A documented dependency override, an entry of
/// `dependency_policy.overrides.allowed`.
final class AllowedOverride {
  /// Creates the justification of overriding [name] because of [reason],
  /// valid through the day [expires] when one is given.
  const AllowedOverride({
    required this.name,
    required this.reason,
    this.expires,
  });

  /// Parses one [entry] of the list at [path].
  ///
  /// Returns the justification.
  ///
  /// Throws an [InspectraConfigException] for a malformed entry.
  factory AllowedOverride._fromEntry(Object? entry, String path) {
    if (entry is! Map) {
      throw InspectraConfigException(
        path,
        'expected a mapping with name and reason.',
      );
    }
    const allowed = <String>{'name', 'reason', 'expires'};
    final Iterable<Object?> unknown = entry.keys.where(
      (key) => !allowed.contains('$key'),
    );
    if (unknown.isNotEmpty) {
      throw InspectraConfigException(
        '$path.${unknown.first}',
        'unknown option.${didYouMean('${unknown.first}', allowed)} Known '
            'options here: name, reason, expires.',
      );
    }
    final String? name = _text(entry['name']);
    final String? reason = _text(entry['reason']);
    if (name == null) {
      throw InspectraConfigException(
        '$path.name',
        'a package name is required.',
      );
    }
    if (reason == null) {
      throw InspectraConfigException(
        '$path.reason',
        'a reason is required, so that everyone knows why the override is '
            'needed.',
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
    return AllowedOverride(name: name, reason: reason, expires: expires);
  }

  /// Reads the `allowed` list of the `overrides` section in [yaml]; only
  /// the configuration file can express it, and every layer adds to it.
  ///
  /// Returns the justifications, empty when the list is absent.
  ///
  /// Throws an [InspectraConfigException] for malformed entries, entries
  /// without `name` or `reason`, and unknown keys.
  static List<AllowedOverride> listFromYaml(YamlReader yaml) {
    final entries = <AllowedOverride>[];
    for (final (Object? raw, String path, String? file)
        in yaml.structuredLayers('allowed', fallback: const <Object?>[])) {
      if (raw == null) {
        continue;
      }
      if (raw is! List) {
        throw InspectraConfigException(
          path,
          'expected a list of entries with name and reason.',
          file: file,
        );
      }
      for (var index = 0; index < raw.length; index++) {
        try {
          entries.add(AllowedOverride._fromEntry(raw[index], '$path[$index]'));
        } on InspectraConfigException catch (error) {
          throw InspectraConfigException(
            error.path,
            error.message,
            file: file ?? error.file,
          );
        }
      }
    }
    return List<AllowedOverride>.unmodifiable(entries);
  }

  /// The overridden package.
  final String name;

  /// Why the override is needed.
  final String reason;

  /// The last day the justification holds, or `null` when it does not
  /// expire.
  final DateTime? expires;

  /// Whether the justification has expired at [now]; it holds through the
  /// whole day of [expires].
  ///
  /// Returns `true` after the expiry day.
  bool isExpired(DateTime now) {
    final DateTime? last = expires;
    if (last == null) {
      return false;
    }
    final end = DateTime.utc(last.year, last.month, last.day + 1);
    return !now.toUtc().isBefore(end);
  }

  /// Returns [value] as trimmed text, or `null` when absent or blank.
  static String? _text(Object? value) {
    if (value == null) {
      return null;
    }
    final String text = '$value'.trim();
    return text.isEmpty ? null : text;
  }
}
