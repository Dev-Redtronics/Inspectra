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

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as p;

import 'license_header.dart';
import 'style_rule_visitor.dart';
import 'style_violation.dart';

/// Checks Dart files against the code rules of `AGENTS.md` that no lint of
/// the Dart analyzer covers.
///
/// Besides the AST rules of [StyleRuleVisitor] it checks:
///
/// * the Apache-2.0 license header at the top of every file;
/// * that no comment other than `///` documentation exists;
/// * that a file declares at most one top level type, named after the file;
///   a sealed class and its direct subtypes form one family and may share
///   their file, as the language requires.
final class StyleChecker {
  /// Creates a checker.
  const StyleChecker();

  /// Checks the Dart file at [path].
  ///
  /// Returns the violations found.
  List<StyleViolation> checkFile(String path) {
    final content = File(path).readAsStringSync();
    final displayed = p.split(p.relative(path)).join('/');
    final violations = <StyleViolation>[];
    if (!content.startsWith(licenseHeader)) {
      violations.add(
        StyleViolation(
          displayed,
          1,
          'The file must start with the Apache-2.0 license header.',
        ),
      );
    }
    final parsed = parseString(
      content: content,
      path: path,
      throwIfDiagnostics: false,
    );
    final visitor = StyleRuleVisitor(displayed, parsed.lineInfo);
    parsed.unit.accept(visitor);
    violations
      ..addAll(visitor.violations)
      ..addAll(_checkComments(parsed.unit, displayed, parsed.lineInfo))
      ..addAll(_checkTypes(parsed.unit, displayed, path));
    return violations;
  }

  /// Rejects every comment except documentation comments and the license
  /// header.
  ///
  /// Returns the violations.
  List<StyleViolation> _checkComments(
    CompilationUnit unit,
    String path,
    LineInfo lineInfo,
  ) {
    final violations = <StyleViolation>[];
    Token? token = unit.beginToken;
    while (token != null && !token.isEof) {
      Token? comment = token.precedingComments;
      while (comment != null) {
        final lexeme = comment.lexeme;
        final isDoc = lexeme.startsWith('///');
        final isHeader = comment.offset == 0 && lexeme.startsWith('/*');
        if (!isDoc && !isHeader) {
          final line = lineInfo.getLocation(comment.offset).lineNumber;
          violations.add(
            StyleViolation(
              path,
              line,
              'No comments: only /// documentation is allowed.',
            ),
          );
        }
        comment = comment.next;
      }
      token = token.next;
    }
    return violations;
  }

  /// Checks the one-type-per-file rule.
  ///
  /// Returns the violations.
  List<StyleViolation> _checkTypes(
    CompilationUnit unit,
    String displayed,
    String path,
  ) {
    final types = <(String, CompilationUnitMember)>[
      for (final member in unit.declarations)
        if (_typeName(member) case final String name) (name, member),
    ];
    if (types.isEmpty) {
      return const <StyleViolation>[];
    }
    final sealedRoots = <String>{
      for (final (name, member) in types)
        if (member is ClassDeclaration && member.sealedKeyword != null) name,
    };
    final primary = types
        .where((entry) => !_extendsAny(entry.$2, sealedRoots))
        .toList();
    final violations = <StyleViolation>[];
    if (primary.length > 1) {
      violations.add(
        StyleViolation(
          displayed,
          1,
          'One top level type per file: found ${primary.map((e) => e.$1).join(', ')}.',
        ),
      );
    }
    final expected = _snakeCase(primary.first.$1);
    final actual = p.basenameWithoutExtension(path);
    if (primary.length == 1 && expected != actual) {
      violations.add(
        StyleViolation(
          displayed,
          1,
          'The file declaring ${primary.first.$1} must be named $expected.dart.',
        ),
      );
    }
    return violations;
  }

  /// Returns the declared type name of [member], or `null` for functions
  /// and variables.
  String? _typeName(CompilationUnitMember member) {
    if (member is ClassDeclaration) {
      return member.namePart.typeName.lexeme;
    }
    if (member is EnumDeclaration) {
      return member.namePart.typeName.lexeme;
    }
    if (member is ExtensionTypeDeclaration) {
      return member.namePart.typeName.lexeme;
    }
    if (member is MixinDeclaration) {
      return member.name.lexeme;
    }
    if (member is TypeAlias) {
      return member.name.lexeme;
    }
    if (member is ExtensionDeclaration) {
      return member.name?.lexeme ?? 'unnamed extension';
    }
    return null;
  }

  /// Whether [member] directly extends or implements one of [roots].
  ///
  /// Returns `true` for members of a sealed family.
  bool _extendsAny(CompilationUnitMember member, Set<String> roots) {
    if (member is! ClassDeclaration) {
      return false;
    }
    final superclass = member.extendsClause?.superclass.name.lexeme;
    final interfaces =
        member.implementsClause?.interfaces.map((type) => type.name.lexeme) ??
        const <String>[];
    return roots.contains(superclass) || interfaces.any(roots.contains);
  }

  /// Converts an upper camel case [name] to snake case.
  ///
  /// Returns the snake case name, for example `cvss_v3_calculator`.
  String _snakeCase(String name) {
    final withBreaks = name
        .replaceAllMapped(
          RegExp('([a-z0-9])([A-Z])'),
          (match) => '${match[1]}_${match[2]}',
        )
        .replaceAllMapped(
          RegExp('([A-Z])([A-Z][a-z])'),
          (match) => '${match[1]}_${match[2]}',
        );
    return withBreaks.toLowerCase();
  }
}
