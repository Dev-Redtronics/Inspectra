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

import 'package:inspectra/src/cli/package_check_command.dart';

/// `inspectra api check`: fails when the public API differs from its
/// committed dump.
final class ApiCheckCommand extends PackageCheckCommand {
  /// Creates the command.
  ApiCheckCommand(super.context);

  /// The command name.
  @override
  String get name => 'check';

  /// The one line description.
  @override
  String get description =>
      'Fail when the public API differs from its committed dump.';

  /// Runs the API check.
  ///
  /// Returns whether it passed.
  @override
  Future<bool> runChecks() => runApiCheck(loadPackageConfig());
}
