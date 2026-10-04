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

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/report/command_report.dart';

/// A minimal report used to exercise the generic writers.
final class SampleReport implements CommandReport {
  /// Creates a report with [findings].
  const SampleReport(this.findings);

  /// The findings.
  @override
  final List<Finding> findings;

  /// The command name.
  @override
  String get command => 'sample';

  /// Fails on any finding at or above [threshold].
  @override
  bool isFailing(Severity threshold) =>
      findings.any((f) => f.severity.isAtLeast(threshold));

  /// Returns a body without a `findings` key.
  @override
  Map<String, Object?> toJson() => <String, Object?>{'custom': true};

  /// Writes nothing.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {}
}
