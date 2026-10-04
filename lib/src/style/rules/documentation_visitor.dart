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

/// Reports declarations without a `///` documentation comment, either the
/// public or the private ones.
///
/// A declaration is private when its name starts with `_` or when it is a
/// member of a private type or of an unnamed extension. Local functions
/// and variables are statements and never need documentation.
final class DocumentationVisitor extends RecursiveAstVisitor<void> {
  /// Creates a visitor reporting to [reporter] the undocumented private
  /// declarations when [private] is `true`, and the public ones otherwise.
  DocumentationVisitor(this.reporter, {required this.private});

  /// Receives the violations.
  final StyleReporter reporter;

  /// Whether private rather than public declarations are checked.
  final bool private;

  /// Whether the type being visited is private.
  var _insidePrivateType = false;

  /// Reports [node], a [kind] called [name], when it is undocumented and
  /// its privacy, [isPrivate], is the one checked.
  void _require(AnnotatedNode node, String kind, String name, bool isPrivate) {
    if (isPrivate != private || node.documentationComment != null) {
      return;
    }
    final visibility = private ? 'private' : 'public';
    reporter.reportAt(
      node.firstTokenAfterCommentAndMetadata,
      'The $visibility $kind $name needs a /// documentation comment.',
    );
  }

  /// Runs [visitMembers] for a type that is private when [isPrivate].
  void _withinType(bool isPrivate, void Function() visitMembers) {
    final bool outer = _insidePrivateType;
    _insidePrivateType = isPrivate;
    visitMembers();
    _insidePrivateType = outer;
  }

  /// Checks a class and its members.
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final String name = node.namePart.typeName.lexeme;
    final bool isPrivate = _isPrivate(name);
    _require(node, 'class', name, isPrivate);
    _withinType(isPrivate, () => super.visitClassDeclaration(node));
  }

  /// Checks a mixin and its members.
  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    final String name = node.name.lexeme;
    final bool isPrivate = _isPrivate(name);
    _require(node, 'mixin', name, isPrivate);
    _withinType(isPrivate, () => super.visitMixinDeclaration(node));
  }

  /// Checks an enum, its values and its members.
  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    final String name = node.namePart.typeName.lexeme;
    final bool isPrivate = _isPrivate(name);
    _require(node, 'enum', name, isPrivate);
    _withinType(isPrivate, () => super.visitEnumDeclaration(node));
  }

  /// Checks an enum value.
  @override
  void visitEnumConstantDeclaration(EnumConstantDeclaration node) {
    _require(node, 'enum value', node.name.lexeme, _insidePrivateType);
    super.visitEnumConstantDeclaration(node);
  }

  /// Checks an extension and its members; unnamed extensions are private.
  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    final String? name = node.name?.lexeme;
    final bool isPrivate = name == null || _isPrivate(name);
    _require(node, 'extension', name ?? '(unnamed)', isPrivate);
    _withinType(isPrivate, () => super.visitExtensionDeclaration(node));
  }

  /// Checks an extension type and its members.
  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    final String name = node.namePart.typeName.lexeme;
    final bool isPrivate = _isPrivate(name);
    _require(node, 'extension type', name, isPrivate);
    _withinType(isPrivate, () => super.visitExtensionTypeDeclaration(node));
  }

  /// Checks a typedef.
  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    final String name = node.name.lexeme;
    _require(node, 'typedef', name, _isPrivate(name));
    super.visitGenericTypeAlias(node);
  }

  /// Checks a typedef in the old function type syntax.
  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    final String name = node.name.lexeme;
    _require(node, 'typedef', name, _isPrivate(name));
    super.visitFunctionTypeAlias(node);
  }

  /// Checks a top level function; local functions are exempt.
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.parent is CompilationUnit) {
      final String name = node.name.lexeme;
      _require(node, 'function', name, _isPrivate(name));
    }
    super.visitFunctionDeclaration(node);
  }

  /// Checks a top level variable declaration.
  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    final NodeList<VariableDeclaration> variables = node.variables.variables;
    _require(
      node,
      'variable',
      variables.map((variable) => variable.name.lexeme).join(', '),
      variables.every((variable) => _isPrivate(variable.name.lexeme)),
    );
    super.visitTopLevelVariableDeclaration(node);
  }

  /// Checks a constructor.
  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final String? name = node.name?.lexeme;
    final String type = node.typeName?.name ?? '';
    _require(
      node,
      'constructor',
      name == null ? type : '$type.$name',
      _insidePrivateType || (name != null && _isPrivate(name)),
    );
    super.visitConstructorDeclaration(node);
  }

  /// Checks a method, getter, setter or operator.
  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final String name = node.name.lexeme;
    _require(node, 'member', name, _insidePrivateType || _isPrivate(name));
    super.visitMethodDeclaration(node);
  }

  /// Checks a field declaration.
  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    final NodeList<VariableDeclaration> variables = node.fields.variables;
    _require(
      node,
      'field',
      variables.map((variable) => variable.name.lexeme).join(', '),
      _insidePrivateType ||
          variables.every((variable) => _isPrivate(variable.name.lexeme)),
    );
    super.visitFieldDeclaration(node);
  }

  /// Whether [name] is library private.
  bool _isPrivate(String name) => name.startsWith('_');
}
