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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:inspectra/src/style/style_reporter.dart';

/// Finds `else` keywords.
final class ElseVisitor extends RecursiveAstVisitor<void> {
  /// Creates a visitor reporting to [reporter].
  ElseVisitor(this.reporter);

  /// Receives the violations.
  final StyleReporter reporter;

  /// Reports the `else` of an `if` statement.
  @override
  void visitIfStatement(IfStatement node) {
    final Token? keyword = node.elseKeyword;
    if (keyword != null) {
      reporter.reportAt(keyword, 'No else: return early instead.');
    }
    super.visitIfStatement(node);
  }

  /// Reports the `else` of a collection `if` element.
  @override
  void visitIfElement(IfElement node) {
    final Token? keyword = node.elseKeyword;
    if (keyword != null) {
      reporter.reportAt(
        keyword,
        'No else: split the collection element instead.',
      );
    }
    super.visitIfElement(node);
  }
}
