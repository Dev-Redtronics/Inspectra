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

import 'package:inspectra/src/style/rules/wildcard_case_visitor.dart';
import 'package:inspectra/src/style/style_file.dart';
import 'package:inspectra/src/style/style_reporter.dart';
import 'package:inspectra/src/style/style_rule.dart';

/// `no_wildcard_case`: no `_` case in `switch` statements and expressions,
/// the pattern equivalent of `default`.
final class NoWildcardCaseRule extends StyleRule {
  /// Creates the rule.
  const NoWildcardCaseRule();

  /// The rule id.
  @override
  String get id => 'no_wildcard_case';

  /// What the rule requires.
  @override
  String get description =>
      'No wildcard case in switch statements and expressions: handle every '
      'case explicitly.';

  /// Reports every wildcard case.
  @override
  void check(StyleFile file, StyleReporter reporter) =>
      file.unit.accept(WildcardCaseVisitor(reporter));
}
