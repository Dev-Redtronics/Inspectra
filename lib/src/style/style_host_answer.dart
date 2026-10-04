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

import 'package:inspectra/src/style/style_violation.dart';

/// What the custom rule program returned.
final class StyleHostAnswer {
  /// Creates an answer listing every custom rule's description by id in
  /// [rules] and the [violations] of the rules that ran.
  const StyleHostAnswer({required this.rules, required this.violations});

  /// The description of every custom rule, by id.
  final Map<String, String> rules;

  /// The violations of the rules that ran.
  final List<StyleViolation> violations;
}
