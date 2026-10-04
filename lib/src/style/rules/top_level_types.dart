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

/// Lists the top level types of [unit] that count as the file's own types:
/// classes, mixins, enums, extensions, extension types and typedefs, except
/// the direct subtypes of a sealed class declared in the same file, which
/// the language requires to live with it.
///
/// Returns the names and declarations in file order.
List<(String, CompilationUnitMember)> primaryTypes(CompilationUnit unit) {
  final types = <(String, CompilationUnitMember)>[
    for (final CompilationUnitMember member in unit.declarations)
      if (typeName(member) case final String name) (name, member),
  ];
  final sealedRoots = <String>{
    for (final (name, member) in types)
      if (member is ClassDeclaration && member.sealedKeyword != null) name,
  };
  return <(String, CompilationUnitMember)>[
    for (final type in types)
      if (!_extendsAny(type.$2, sealedRoots)) type,
  ];
}

/// Lists the [primaryTypes] of [unit] whose names are public; an unnamed
/// extension is private.
///
/// Returns the names and declarations in file order.
List<(String, CompilationUnitMember)> publicTypes(CompilationUnit unit) =>
    <(String, CompilationUnitMember)>[
      for (final type in primaryTypes(unit))
        if (!type.$1.startsWith('_') && type.$1 != unnamedExtension) type,
    ];

/// The name [typeName] gives an extension without a name.
const unnamedExtension = 'unnamed extension';

/// Returns the declared type name of [member], or `null` for functions and
/// variables; an unnamed extension is called `unnamed extension`.
String? typeName(CompilationUnitMember member) {
  if (member is TypeAlias) {
    return member.name.lexeme;
  }
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
  if (member is ExtensionDeclaration) {
    return member.name?.lexeme ?? unnamedExtension;
  }
  return null;
}

/// Converts an upper camel case [name] to lower snake case.
///
/// Returns the snake case name, for example `cvss_v3_calculator` for
/// `CvssV3Calculator` and `http_client` for `HTTPClient`.
String snakeCase(String name) {
  final String withBreaks = name
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

/// Whether [member] directly extends or implements one of [roots].
///
/// Returns `true` for the members of a sealed family.
bool _extendsAny(CompilationUnitMember member, Set<String> roots) {
  if (member is! ClassDeclaration) {
    return false;
  }
  final String? superclass = member.extendsClause?.superclass.name.lexeme;
  final Iterable<String> interfaces =
      member.implementsClause?.interfaces.map((type) => type.name.lexeme) ??
      const <String>[];
  return roots.contains(superclass) || interfaces.any(roots.contains);
}
