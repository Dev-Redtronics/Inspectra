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

import 'package:inspectra/style.dart';

/// A custom rule that reports calls of `print`.
final class NoPrintRule extends StyleRule {
  /// Creates the rule.
  const NoPrintRule();

  /// The rule id.
  @override
  String get id => 'no_print';

  /// What the rule requires.
  @override
  String get description => 'No print.';

  /// Reports every `print(`.
  @override
  void check(StyleFile file, StyleReporter reporter) {
    final int offset = file.content.indexOf('print(');
    if (offset >= 0) {
      reporter.reportOffset(offset, 'Use a logger.');
    }
  }
}
