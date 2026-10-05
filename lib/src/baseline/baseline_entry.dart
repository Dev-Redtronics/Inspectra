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

import 'package:inspectra/src/baseline/baseline_candidate.dart';
import 'package:inspectra/src/baseline/baseline_scope.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/model/severity.dart';

/// One recorded finding of a baseline: a key and how often it occurred.
final class BaselineEntry {
  /// Creates an entry.
  const BaselineEntry({
    required this.scope,
    required this.source,
    required this.rule,
    required this.count,
    required this.severity,
    required this.title,
    this.package,
    this.path,
  });

  /// Reads the entry [json], found at [location] of the baseline file.
  ///
  /// Returns the entry.
  ///
  /// Throws an [InvalidInputException] naming [location] when a field is
  /// missing, has the wrong type or an unknown value.
  factory BaselineEntry.fromJson(Object? json, String location) {
    if (json is! Map<String, Object?>) {
      throw InvalidInputException('$location must be an object.');
    }
    final Iterable<String> unknown = json.keys.where(
      (key) => !_fields.contains(key),
    );
    if (unknown.isNotEmpty) {
      throw InvalidInputException(
        '$location has the unknown field "${unknown.first}".',
      );
    }
    final String scopeId = _text(json, 'scope', location);
    final BaselineScope? scope = BaselineScope.tryParse(scopeId);
    if (scope == null) {
      throw InvalidInputException(
        '$location has the unknown scope "$scopeId".',
      );
    }
    final String severityName = _text(json, 'severity', location);
    final Iterable<Severity> severities = Severity.values.where(
      (severity) => severity.name == severityName,
    );
    if (severities.isEmpty) {
      throw InvalidInputException(
        '$location has the unknown severity "$severityName".',
      );
    }
    final Object? count = json['count'];
    if (count is! int || count < 1) {
      throw InvalidInputException('$location needs a "count" of at least 1.');
    }
    return BaselineEntry(
      scope: scope,
      source: _text(json, 'source', location),
      rule: _text(json, 'rule', location),
      count: count,
      severity: severities.first,
      title: _text(json, 'title', location),
      package: _optionalText(json, 'package', location),
      path: _optionalText(json, 'path', location),
    );
  }

  /// The fields an entry may have.
  static const _fields = <String>{
    'scope',
    'source',
    'rule',
    'package',
    'path',
    'count',
    'severity',
    'title',
  };

  /// The scope the finding belongs to.
  final BaselineScope scope;

  /// What reported the finding within its scope.
  final String source;

  /// The rule, advisory or diagnostic code.
  final String rule;

  /// How many findings of this key are covered.
  final int count;

  /// The highest severity among the recorded findings.
  final Severity severity;

  /// A one-line description of the first recorded finding.
  final String title;

  /// The affected package, if any.
  final String? package;

  /// The affected file relative to the package root, if any.
  final String? path;

  /// The identity this entry covers; see [BaselineCandidate.key].
  String get key => baselineKey(
    scope: scope,
    source: source,
    rule: rule,
    package: package,
    path: path,
  );

  /// Returns a copy of this entry that covers [count] findings.
  BaselineEntry withCount(int count) => BaselineEntry(
    scope: scope,
    source: source,
    rule: rule,
    count: count,
    severity: severity,
    title: title,
    package: package,
    path: path,
  );

  /// Serializes the entry for the baseline file.
  ///
  /// Returns the JSON object.
  Map<String, Object?> toJson() => <String, Object?>{
    'scope': scope.id,
    'source': source,
    'rule': rule,
    if (package != null) 'package': package,
    if (path != null) 'path': path,
    'count': count,
    'severity': severity.name,
    'title': title,
  };

  /// Reads the required text field [key] of [json] at [location].
  ///
  /// Returns the text.
  ///
  /// Throws an [InvalidInputException] when it is missing or not a string.
  static String _text(Map<String, Object?> json, String key, String location) {
    final Object? value = json[key];
    if (value is! String) {
      throw InvalidInputException('$location needs a "$key" text.');
    }
    return value;
  }

  /// Reads the optional text field [key] of [json] at [location].
  ///
  /// Returns the text, or `null` when it is absent.
  ///
  /// Throws an [InvalidInputException] when it is present but not a string.
  static String? _optionalText(
    Map<String, Object?> json,
    String key,
    String location,
  ) {
    final Object? value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw InvalidInputException('$location has a "$key" that is no text.');
    }
    return value;
  }
}
