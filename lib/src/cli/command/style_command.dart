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

import 'package:args/args.dart';
import 'package:inspectra/src/baseline/baseline_gates.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/inspectra_command.dart';
import 'package:inspectra/src/quality/quality_command.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/style/style_report.dart';
import 'package:inspectra/src/style/style_result.dart';

/// `inspectra style`: checks the Dart files against the built-in and
/// custom style rules selected by the `style:` section.
final class StyleCommand extends InspectraCommand {
  /// Creates the command.
  StyleCommand(super.context);

  /// The command name.
  @override
  String get name => 'style';

  /// The one line description.
  @override
  String get description =>
      'Check the Dart files against the built-in and custom style rules.';

  /// Runs the style check, whether or not `style.enabled` is set.
  ///
  /// Returns the style report.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    final StyleResult result = await runStyleCheck(
      session.config,
      session.workingDirectory,
    );
    return StyleReport(baselineStyle(result, session.baselineMatcher()));
  }
}
