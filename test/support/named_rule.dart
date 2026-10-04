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

/// A rule that never reports, with a configurable id.
final class NamedRule extends StyleRule {
  /// Creates the rule with the [id].
  const NamedRule(this.id);

  /// The rule id.
  @override
  final String id;

  /// What the rule requires.
  @override
  String get description => 'Quiet.';

  /// Reports nothing.
  @override
  void check(StyleFile file, StyleReporter reporter) {}
}
