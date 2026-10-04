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

/// One place where a Dart file breaks a style rule.
final class StyleViolation {
  /// Creates a violation of the rule [ruleId] in the file [path] at the
  /// one-based [line] and [column], described by [message].
  const StyleViolation({
    required this.ruleId,
    required this.path,
    required this.line,
    required this.column,
    required this.message,
  });

  /// Reads a violation written by [toJson].
  ///
  /// Returns the violation.
  ///
  /// Throws a [FormatException] when [json] is not such an object.
  factory StyleViolation.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('A style violation must be an object.');
    }
    final Object? ruleId = json['rule'];
    final Object? path = json['path'];
    final Object? line = json['line'];
    final Object? column = json['column'];
    final Object? message = json['message'];
    final bool valid =
        ruleId is String &&
        path is String &&
        line is int &&
        column is int &&
        message is String;
    if (!valid) {
      throw FormatException('Malformed style violation: $json');
    }
    return StyleViolation(
      ruleId: ruleId,
      path: path,
      line: line,
      column: column,
      message: message,
    );
  }

  /// The id of the broken rule, such as `no_else`.
  final String ruleId;

  /// The file, relative to the package root, with `/` as separator.
  final String path;

  /// The one-based line.
  final int line;

  /// The one-based column.
  final int column;

  /// What is wrong and how to fix it.
  final String message;

  /// Serialises the violation for reports and the custom rule host.
  ///
  /// Returns the JSON object.
  Map<String, Object?> toJson() => <String, Object?>{
    'rule': ruleId,
    'path': path,
    'line': line,
    'column': column,
    'message': message,
  };

  /// Returns `path:line:column: message [rule]`, the form editors and CI
  /// logs link to.
  @override
  String toString() => '$path:$line:$column: $message [$ruleId]';
}
