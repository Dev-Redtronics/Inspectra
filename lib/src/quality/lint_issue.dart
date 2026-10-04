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

import 'package:inspectra/src/config/inspectra_config.dart';

/// One diagnostic reported by `dart analyze`.
class LintIssue {
  /// Creates a diagnostic.
  const LintIssue({
    required this.severity,
    required this.type,
    required this.code,
    required this.path,
    required this.line,
    required this.column,
    required this.message,
  });

  /// `error`, `warning` or `info`.
  final LintLevel severity;

  /// The kind of diagnostic, such as `LINT`, `HINT`, `STATIC_WARNING` or
  /// `COMPILE_TIME_ERROR`.
  final String type;

  /// The diagnostic or lint name, lower case, such as `prefer_single_quotes`.
  final String code;

  /// The file, relative to the package root.
  final String path;

  /// The 1-based line.
  final int line;

  /// The 1-based column.
  final int column;

  /// The analyzer's message.
  final String message;

  /// Serializes this diagnostic for the JSON report.
  Map<String, Object?> toJson() => {
    'severity': severity.name,
    'type': type,
    'code': code,
    'path': path,
    'line': line,
    'column': column,
    'message': message,
  };
}
