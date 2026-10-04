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

import 'package:yaml/yaml.dart';

/// Converts parsed YAML nodes into plain Dart maps, lists and scalars, with
/// every map key turned into a string.
///
/// Parsers of `pubspec.yaml` and `pubspec.lock` use it to work with ordinary
/// `Map<String, Object?>` values and pattern matching instead of YAML node
/// types.
///
/// Returns the converted value.
Object? toPlainValue(Object? value) {
  if (value is YamlMap) {
    return <String, Object?>{
      for (final entry in value.entries)
        '${entry.key}': toPlainValue(entry.value),
    };
  }
  if (value is YamlList) {
    return value.map(toPlainValue).toList();
  }
  return value;
}
