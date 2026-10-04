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

import 'package:inspectra/src/api/api_command.dart';
import 'package:inspectra/src/cli/package_check_command.dart';

/// `inspectra api dump`: writes the public API of the package to its dump.
final class ApiDumpCommand extends PackageCheckCommand {
  /// Creates the command.
  ApiDumpCommand(super.context);

  /// The command name.
  @override
  String get name => 'dump';

  /// The one line description.
  @override
  String get description => 'Write the public API of the package to its dump.';

  /// Writes the dump.
  ///
  /// Returns `true`; writing the dump cannot fail a check.
  @override
  Future<bool> runChecks() async {
    final String path = await dumpApi(loadPackageConfig(), packageRoot);
    out.writeln('Wrote the public API to $path.');
    return true;
  }
}
