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
import 'package:inspectra/src/trivy/trivy.dart';

/// The findings for one target of a Trivy report.
class TrivyResult {
  /// Wraps the decoded JSON of one result.
  const TrivyResult(this._json);

  /// The decoded JSON of the result.
  final Map<String, Object?> _json;

  /// The scanned file, relative to the scan target.
  String get target => trivyString(_json, 'Target');

  /// The secrets found in [target].
  List<Map<String, Object?>> get secrets => _entries('Secrets');

  /// The vulnerabilities found in [target].
  List<Map<String, Object?>> get vulnerabilities => _entries('Vulnerabilities');

  /// The licenses found in [target].
  List<Map<String, Object?>> get licenses => _entries('Licenses');

  /// The misconfigurations found in [target].
  List<Map<String, Object?>> get misconfigurations =>
      _entries('Misconfigurations');

  /// The entries of the list [key] that are JSON objects, or an empty list
  /// when the result has no such list.
  List<Map<String, Object?>> _entries(String key) {
    final Object? value = _json[key];
    if (value is! List) {
      return const [];
    }
    return [
      for (final entry in value)
        if (entry is Map<String, Object?>) entry,
    ];
  }
}
