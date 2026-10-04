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

/// Custom style rules for `inspectra style`.
///
/// A package writes its own rules against the syntax tree of the Dart
/// analyzer, declares them in a top level `styleRules` and lists the file
/// in `style.custom_rules`:
///
/// ```dart
/// import 'package:analyzer/dart/ast/ast.dart';
/// import 'package:analyzer/dart/ast/visitor.dart';
/// import 'package:inspectra/style.dart';
///
/// final styleRules = <StyleRule>[const NoPrintRule()];
///
/// final class NoPrintRule extends StyleRule {
///   const NoPrintRule();
///
///   @override
///   String get id => 'no_print';
///
///   @override
///   String get description => 'Use a logger instead of print.';
///
///   @override
///   void check(StyleFile file, StyleReporter reporter) =>
///       file.unit.accept(_PrintFinder(reporter));
/// }
/// ```
///
/// `StyleChecker` runs rules on source text, which is how their tests
/// work.
library;

export 'src/style/style_checker.dart' show StyleChecker;
export 'src/style/style_file.dart';
export 'src/style/style_host_entry.dart';
export 'src/style/style_reporter.dart';
export 'src/style/style_rule.dart';
export 'src/style/style_violation.dart';
