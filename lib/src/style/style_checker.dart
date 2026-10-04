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

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:inspectra/src/style/style_file.dart';
import 'package:inspectra/src/style/style_reporter.dart';
import 'package:inspectra/src/style/style_rule.dart';
import 'package:inspectra/src/style/style_suppressions.dart';
import 'package:inspectra/src/style/style_violation.dart';

/// Runs style rules over Dart source.
///
/// It is also the way to test a custom rule:
///
/// ```dart
/// final violations = StyleChecker([const NoPrintRule()])
///     .checkSource('lib/a.dart', "void f() => print('x');");
/// expect(violations.single.ruleId, 'no_print');
/// ```
final class StyleChecker {
  /// Creates a checker running [rules].
  const StyleChecker(this.rules);

  /// The rules to run.
  final List<StyleRule> rules;

  /// Parses [content], the text of the file at [path] relative to the
  /// package root, and runs every rule on it. Violations suppressed by an
  /// `// inspectra: ignore-style` comment are left out.
  ///
  /// The file is parsed with error recovery, so a file with syntax errors
  /// is still checked as far as it can be read.
  ///
  /// Returns the violations sorted by line, column and rule.
  List<StyleViolation> checkSource(String path, String content) {
    final ParseStringResult parsed = parseString(
      content: content,
      path: path,
      throwIfDiagnostics: false,
    );
    final file = StyleFile(
      path: path,
      content: content,
      unit: parsed.unit,
      lineInfo: parsed.lineInfo,
    );
    final suppressions = StyleSuppressions.parse(content);
    final violations = <StyleViolation>[];
    for (final StyleRule rule in rules) {
      final reporter = StyleReporter(rule.id, file);
      rule.check(file, reporter);
      violations.addAll(
        reporter.violations.where((v) => !suppressions.suppresses(v)),
      );
    }
    return violations..sort(compareStyleViolations);
  }
}

/// Orders violations by path, line, column and rule.
///
/// Returns a negative number when [a] comes first, a positive number when
/// [b] comes first, and zero when they are at the same place.
int compareStyleViolations(StyleViolation a, StyleViolation b) {
  final int byPath = a.path.compareTo(b.path);
  if (byPath != 0) {
    return byPath;
  }
  final int byLine = a.line.compareTo(b.line);
  if (byLine != 0) {
    return byLine;
  }
  final int byColumn = a.column.compareTo(b.column);
  if (byColumn != 0) {
    return byColumn;
  }
  return a.ruleId.compareTo(b.ruleId);
}
