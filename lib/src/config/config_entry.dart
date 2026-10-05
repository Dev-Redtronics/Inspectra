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

import 'package:inspectra/src/config/config_kind.dart';
import 'package:inspectra/src/config/config_origin.dart';

/// The effective value of one configuration option and where it comes from,
/// as a [ConfigKind]ed description that also yields its JSON Schema.
final class ConfigEntry {
  /// Creates the entry of the option at the dotted [key].
  ///
  /// [value] and [defaultValue] are JSON values: booleans, numbers, texts,
  /// lists and maps, with durations written as `30s` or `10m`.
  const ConfigEntry({
    required this.key,
    required this.kind,
    required this.value,
    required this.defaultValue,
    required this.origin,
    this.variable,
    this.line,
    this.options,
    this.minimum,
    this.maximum,
  });

  /// The dotted path of the option, such as `trivy.version`.
  final String key;

  /// The type of the option.
  final ConfigKind kind;

  /// The effective value, or `null` when the option is unset.
  final Object? value;

  /// The built-in default, or `null` when the option is unset by default.
  final Object? defaultValue;

  /// Where [value] comes from.
  final ConfigOrigin origin;

  /// The environment variable that set the value, if any.
  final String? variable;

  /// The line of the option in the configuration file, if it is there.
  final int? line;

  /// The allowed names of a [ConfigKind.choice] or [ConfigKind.enumList].
  final List<String>? options;

  /// The smallest allowed number, if any.
  final num? minimum;

  /// The largest allowed number, if any.
  final num? maximum;

  /// Serializes the entry for the JSON report of `config show`.
  ///
  /// Returns the JSON object.
  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'value': value,
    'default': defaultValue,
    'origin': origin.id,
    'variable': ?variable,
    'line': ?line,
  };

  /// Converts a value read from the configuration into a JSON value.
  ///
  /// Returns [value] with durations written as `500ms`, `30s`, `10m` or
  /// `1h`, YAML collections as plain lists and maps, and anything else
  /// that is no JSON value as its text.
  static Object? jsonOf(Object? value) {
    if (value == null || value is bool || value is num || value is String) {
      return value;
    }
    if (value is Duration) {
      return formatDuration(value);
    }
    if (value is List<Object?>) {
      return <Object?>[for (final item in value) jsonOf(item)];
    }
    if (value is Map<Object?, Object?>) {
      return <String, Object?>{
        for (final MapEntry<Object?, Object?> entry in value.entries)
          '${entry.key}': jsonOf(entry.value),
      };
    }
    return '$value';
  }

  /// Writes [duration] in the largest unit that divides it.
  ///
  /// Returns a text such as `10m`.
  static String formatDuration(Duration duration) {
    final int milliseconds = duration.inMilliseconds;
    const units = <(int, String)>[
      (60 * 60 * 1000, 'h'),
      (60 * 1000, 'm'),
      (1000, 's'),
    ];
    for (final (size, unit) in units) {
      if (milliseconds != 0 && milliseconds % size == 0) {
        return '${milliseconds ~/ size}$unit';
      }
    }
    return milliseconds == 0 ? '0s' : '${milliseconds}ms';
  }
}
