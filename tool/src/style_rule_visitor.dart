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
import 'package:analyzer/source/line_info.dart';

import 'style_violation.dart';

/// Walks a parsed Dart file and records every breach of the AST based code
/// rules of `AGENTS.md`:
///
/// * no `else` in `if` statements and collection `if` elements;
/// * no `default` and no wildcard `_` case in `switch` statements and
///   expressions;
/// * a `///` documentation comment on every class, mixin, enum, enum value,
///   extension, typedef, top level function and variable, constructor,
///   method and field, including private ones.
final class StyleRuleVisitor extends RecursiveAstVisitor<void> {
  /// Creates a visitor reporting violations of the file at [path], whose
  /// [lineInfo] maps offsets to lines.
  StyleRuleVisitor(this.path, this.lineInfo);

  /// The file being checked.
  final String path;

  /// Maps offsets to line numbers.
  final LineInfo lineInfo;

  /// The recorded violations.
  final List<StyleViolation> violations = <StyleViolation>[];

  /// Records a violation at [node] with [message].
  void _report(AstNode node, String message) {
    final line = lineInfo.getLocation(node.offset).lineNumber;
    violations.add(StyleViolation(path, line, message));
  }

  /// Records a violation when [node] has no documentation comment.
  void _requireDoc(AnnotatedNode node, String kind) {
    if (node.documentationComment != null) {
      return;
    }
    _report(node, 'Every $kind needs a /// documentation comment.');
  }

  /// Rejects `else` branches.
  @override
  void visitIfStatement(IfStatement node) {
    if (node.elseKeyword != null) {
      _report(node, 'No else: return early instead.');
    }
    super.visitIfStatement(node);
  }

  /// Rejects `else` in collection `if` elements.
  @override
  void visitIfElement(IfElement node) {
    if (node.elseKeyword != null) {
      _report(node, 'No else: split the collection element instead.');
    }
    super.visitIfElement(node);
  }

  /// Rejects `default` cases.
  @override
  void visitSwitchDefault(SwitchDefault node) {
    _report(node, 'No default case: handle every case explicitly.');
    super.visitSwitchDefault(node);
  }

  /// Rejects wildcard cases in switch statements.
  @override
  void visitSwitchPatternCase(SwitchPatternCase node) {
    if (node.guardedPattern.pattern is WildcardPattern) {
      _report(node, 'No wildcard case: handle every case explicitly.');
    }
    super.visitSwitchPatternCase(node);
  }

  /// Rejects wildcard cases in switch expressions.
  @override
  void visitSwitchExpressionCase(SwitchExpressionCase node) {
    if (node.guardedPattern.pattern is WildcardPattern) {
      _report(node, 'No wildcard case: handle every case explicitly.');
    }
    super.visitSwitchExpressionCase(node);
  }

  /// Requires documentation on classes.
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _requireDoc(node, 'class');
    super.visitClassDeclaration(node);
  }

  /// Requires documentation on mixins.
  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _requireDoc(node, 'mixin');
    super.visitMixinDeclaration(node);
  }

  /// Requires documentation on enums.
  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    _requireDoc(node, 'enum');
    super.visitEnumDeclaration(node);
  }

  /// Requires documentation on enum values.
  @override
  void visitEnumConstantDeclaration(EnumConstantDeclaration node) {
    _requireDoc(node, 'enum value');
    super.visitEnumConstantDeclaration(node);
  }

  /// Requires documentation on extensions.
  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    _requireDoc(node, 'extension');
    super.visitExtensionDeclaration(node);
  }

  /// Requires documentation on extension types.
  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    _requireDoc(node, 'extension type');
    super.visitExtensionTypeDeclaration(node);
  }

  /// Requires documentation on typedefs.
  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    _requireDoc(node, 'typedef');
    super.visitGenericTypeAlias(node);
  }

  /// Requires documentation on top level functions; local functions are
  /// statements and exempt.
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.parent is CompilationUnit) {
      _requireDoc(node, 'top level function');
    }
    super.visitFunctionDeclaration(node);
  }

  /// Requires documentation on top level variables.
  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    _requireDoc(node, 'top level variable');
    super.visitTopLevelVariableDeclaration(node);
  }

  /// Requires documentation on constructors.
  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _requireDoc(node, 'constructor');
    super.visitConstructorDeclaration(node);
  }

  /// Requires documentation on methods, getters and setters.
  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _requireDoc(node, 'method');
    super.visitMethodDeclaration(node);
  }

  /// Requires documentation on fields.
  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    _requireDoc(node, 'field');
    super.visitFieldDeclaration(node);
  }
}
