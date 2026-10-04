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

import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:inspectra/src/style/style_file.dart';
import 'package:inspectra/src/style/style_violation.dart';

/// Collects the violations one rule finds in one file.
final class StyleReporter {
  /// Creates a reporter for the rule [ruleId] checking [file].
  StyleReporter(this.ruleId, this.file);

  /// The id of the rule that reports.
  final String ruleId;

  /// The checked file.
  final StyleFile file;

  /// The reported violations, in the order they were reported.
  final violations = <StyleViolation>[];

  /// Reports a violation at the start of [entity], a node or token of the
  /// syntax tree, described by [message].
  void reportAt(SyntacticEntity entity, String message) =>
      reportOffset(entity.offset, message);

  /// Reports a violation at the character [offset] of the file, described
  /// by [message].
  void reportOffset(int offset, String message) {
    final CharacterLocation location = file.lineInfo.getLocation(offset);
    violations.add(
      StyleViolation(
        ruleId: ruleId,
        path: file.path,
        line: location.lineNumber,
        column: location.columnNumber,
        message: message,
      ),
    );
  }

  /// Reports a violation at the start of the one-based [line], described
  /// by [message].
  void reportLine(int line, String message) {
    violations.add(
      StyleViolation(
        ruleId: ruleId,
        path: file.path,
        line: line,
        column: 1,
        message: message,
      ),
    );
  }
}
