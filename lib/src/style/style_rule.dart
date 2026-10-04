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

import 'package:inspectra/src/style/style_file.dart';
import 'package:inspectra/src/style/style_reporter.dart';

/// A style rule: a check of one Dart file that reports violations.
///
/// Inspectra's own rules and the custom rules of a package implement this
/// interface. A rule must be deterministic and must not keep state between
/// files; it may be called for many files in any order.
///
/// ```dart
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
///   void check(StyleFile file, StyleReporter reporter) {
///     file.unit.accept(_PrintVisitor(reporter));
///   }
/// }
/// ```
abstract class StyleRule {
  /// Allows subclasses to have constant constructors.
  const StyleRule();

  /// The unique id of the rule in lower snake case, such as `no_print`. It
  /// is used in the configuration, in ignore comments and in reports.
  String get id;

  /// One sentence describing what the rule requires.
  String get description;

  /// Checks [file] and reports every violation to [reporter].
  void check(StyleFile file, StyleReporter reporter);
}
