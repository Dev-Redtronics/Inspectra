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

/// `one_type_per_file`: a file declares at most one top level type. A
/// sealed class and its direct subtypes count as one, since the language
/// requires them to share a library.
final class OneTypePerFileRule extends StyleRule {
  /// Creates the rule.
  const OneTypePerFileRule();

  /// The rule id.
  @override
  String get id => 'one_type_per_file';

  /// What the rule requires.
  @override
  String get description =>
      'One top level type per file; a sealed class and its direct subtypes '
      'count as one.';

  /// Reports every type after the first.
  @override
  void check(StyleFile file, StyleReporter reporter) {
    final List<(String, CompilationUnitMember)> types = primaryTypes(file.unit);
    if (types.length < 2) {
      return;
    }
    final String first = types.first.$1;
    for (final (name, member) in types.skip(1)) {
      reporter.reportAt(
        member,
        'One top level type per file: move $name out of the file that '
        'declares $first.',
      );
    }
  }
}
