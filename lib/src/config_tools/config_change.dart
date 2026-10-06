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

/// One option whose value differs between two configurations.
final class ConfigChange {
  /// Creates the change of the option [key] from [from] to [to], which is
  /// [weaker] when the new value checks less.
  const ConfigChange({
    required this.key,
    required this.from,
    required this.to,
    this.weaker = false,
  });

  /// The dotted path of the option.
  final String key;

  /// The value in the first configuration, as people see it, or `null`
  /// when unset.
  final Object? from;

  /// The value in the second configuration, as people see it, or `null`
  /// when unset.
  final Object? to;

  /// Whether the second value is weaker than the first, for options whose
  /// values are ordered from weak to strict.
  final bool weaker;

  /// Serializes the change for the JSON report of `config diff`.
  ///
  /// Returns the JSON object.
  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'from': from,
    'to': to,
    'weaker': weaker,
  };
}
