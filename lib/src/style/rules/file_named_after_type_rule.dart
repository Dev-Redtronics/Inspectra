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
import 'package:inspectra/src/style/rules/top_level_types.dart';
import 'package:inspectra/src/style/style_file.dart';
import 'package:inspectra/src/style/style_reporter.dart';
import 'package:inspectra/src/style/style_rule.dart';

/// `file_named_after_type`: a file that declares one top level type, or one
/// public type next to private ones, is named after it in snake case,
/// `UserRepository` in `user_repository.dart`.
final class FileNamedAfterTypeRule extends StyleRule {
  /// Creates the rule.
  const FileNamedAfterTypeRule();

  /// The rule id.
  @override
  String get id => 'file_named_after_type';

  /// What the rule requires.
  @override
  String get description =>
      'A file declaring one top level type, or one public type next to '
      'private ones, is named after it in snake case.';

  /// Reports a file whose name does not match its only type, or its only
  /// public type.
  @override
  void check(StyleFile file, StyleReporter reporter) {
    final List<(String, CompilationUnitMember)> all = primaryTypes(file.unit);
    final List<(String, CompilationUnitMember)> types = all.length == 1
        ? all
        : publicTypes(file.unit);
    if (types.length != 1 || file.isPart) {
      return;
    }
    final (String name, CompilationUnitMember member) = types.single;
    final String expected = snakeCase(name);
    if (expected == file.name) {
      return;
    }
    reporter.reportAt(
      member,
      'The file declaring $name must be named $expected.dart.',
    );
  }
}
