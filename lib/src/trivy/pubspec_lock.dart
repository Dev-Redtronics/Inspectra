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

import 'dart:convert';

import 'package:inspectra/src/trivy/package_graph.dart';
import 'package:yaml/yaml.dart';

/// A parsed `pubspec.lock`.
class PubspecLock {
  /// Creates a lock from its packages.
  const PubspecLock(this.packages);

  /// Parses the content of a `pubspec.lock`.
  factory PubspecLock.parse(String content) {
    final Object? yaml = loadYaml(content);
    final Object? packages = yaml is Map ? yaml['packages'] : null;
    final result = <String, LockedPackage>{};
    if (packages is Map) {
      for (final MapEntry(:key, :value) in packages.entries) {
        if (key is! String || value is! Map) {
          continue;
        }
        final json = jsonDecode(jsonEncode(value)) as Map<String, Object?>;
        result[key] = LockedPackage(
          name: key,
          version: '${value['version'] ?? ''}',
          source: '${value['source'] ?? ''}',
          json: json,
        );
      }
    }
    return PubspecLock(Map.unmodifiable(result));
  }

  /// The locked packages by name.
  final Map<String, LockedPackage> packages;

  /// A lock file holding only the packages in [names].
  ///
  /// It is written as JSON, which every YAML parser - Trivy's included -
  /// reads as YAML.
  String retain(Iterable<String> names) {
    final Map<String, Map<String, Object?>> retained = {
      for (final name in names.toList()..sort())
        if (packages[name] case final package?) name: package.json,
    };
    return const JsonEncoder.withIndent('  ')
        .convert({'packages': retained, 'sdks': <String, Object?>{}});
  }
}
