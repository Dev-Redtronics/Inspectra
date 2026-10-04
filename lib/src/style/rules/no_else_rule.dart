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

import 'package:inspectra/src/style/rules/else_visitor.dart';
import 'package:inspectra/src/style/style_file.dart';
import 'package:inspectra/src/style/style_reporter.dart';
import 'package:inspectra/src/style/style_rule.dart';

/// `no_else`: no `else` branch in `if` statements and collection `if`
/// elements; return early instead.
final class NoElseRule extends StyleRule {
  /// Creates the rule.
  const NoElseRule();

  /// The rule id.
  @override
  String get id => 'no_else';

  /// What the rule requires.
  @override
  String get description =>
      'No else branch: return early or split the collection element.';

  /// Reports every `else`.
  @override
  void check(StyleFile file, StyleReporter reporter) =>
      file.unit.accept(ElseVisitor(reporter));
}
