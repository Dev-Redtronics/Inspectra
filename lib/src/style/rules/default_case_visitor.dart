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
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:inspectra/src/style/style_reporter.dart';

/// Finds `default` cases.
final class DefaultCaseVisitor extends RecursiveAstVisitor<void> {
  /// Creates a visitor reporting to [reporter].
  DefaultCaseVisitor(this.reporter);

  /// Receives the violations.
  final StyleReporter reporter;

  /// Reports the `default` case.
  @override
  void visitSwitchDefault(SwitchDefault node) {
    reporter.reportAt(node, 'No default case: handle every case explicitly.');
    super.visitSwitchDefault(node);
  }
}
