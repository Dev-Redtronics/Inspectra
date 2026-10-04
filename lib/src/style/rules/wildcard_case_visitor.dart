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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:inspectra/src/style/style_reporter.dart';

/// Finds wildcard cases.
final class WildcardCaseVisitor extends RecursiveAstVisitor<void> {
  /// Creates a visitor reporting to [reporter].
  WildcardCaseVisitor(this.reporter);

  /// Receives the violations.
  final StyleReporter reporter;

  /// The message of every violation.
  static const _message = 'No wildcard case: handle every case explicitly.';

  /// Reports a wildcard case of a switch statement.
  @override
  void visitSwitchPatternCase(SwitchPatternCase node) {
    if (node.guardedPattern.pattern is WildcardPattern) {
      reporter.reportAt(node, _message);
    }
    super.visitSwitchPatternCase(node);
  }

  /// Reports a wildcard case of a switch expression.
  @override
  void visitSwitchExpressionCase(SwitchExpressionCase node) {
    if (node.guardedPattern.pattern is WildcardPattern) {
      reporter.reportAt(node, _message);
    }
    super.visitSwitchExpressionCase(node);
  }
}
