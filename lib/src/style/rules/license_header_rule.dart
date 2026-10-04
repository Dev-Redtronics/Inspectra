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

import 'package:inspectra/src/style/license_header.dart';
import 'package:inspectra/src/style/style_file.dart';
import 'package:inspectra/src/style/style_reporter.dart';
import 'package:inspectra/src/style/style_rule.dart';

/// `license_header`: every file starts with the license header of the
/// configured template file.
final class LicenseHeaderRule extends StyleRule {
  /// Creates the rule requiring [header].
  const LicenseHeaderRule(this.header);

  /// The required header.
  final LicenseHeader header;

  /// The rule id.
  @override
  String get id => 'license_header';

  /// What the rule requires.
  @override
  String get description =>
      'Every file starts with the license header of ${header.source}.';

  /// Reports a file that does not start with the header.
  @override
  void check(StyleFile file, StyleReporter reporter) {
    if (header.matchLength(file.content) != null) {
      return;
    }
    reporter.reportLine(
      1,
      'The file must start with the license header of ${header.source}.',
    );
  }
}
