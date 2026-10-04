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

import 'package:inspectra/src/style/rules/documentation_visitor.dart';
import 'package:inspectra/src/style/style_file.dart';
import 'package:inspectra/src/style/style_reporter.dart';
import 'package:inspectra/src/style/style_rule.dart';

/// `private_docs`: every private class, mixin, enum, enum value, extension,
/// extension type, typedef, top level function and variable, constructor,
/// method and field has a `///` documentation comment.
final class PrivateDocsRule extends StyleRule {
  /// Creates the rule.
  const PrivateDocsRule();

  /// The rule id.
  @override
  String get id => 'private_docs';

  /// What the rule requires.
  @override
  String get description =>
      'Every private declaration has a /// documentation comment.';

  /// Reports every undocumented private declaration.
  @override
  void check(StyleFile file, StyleReporter reporter) =>
      file.unit.accept(DocumentationVisitor(reporter, private: true));
}
