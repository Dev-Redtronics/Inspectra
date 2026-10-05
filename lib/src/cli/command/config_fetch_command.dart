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
import 'package:inspectra/src/cli/command/config_tool_command.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/config/config_fetch_outcome.dart';
import 'package:inspectra/src/config/config_layer.dart';
import 'package:inspectra/src/config/config_layer_stack.dart';
import 'package:inspectra/src/config_tools/config_fetch_report.dart';
import 'package:inspectra/src/report/command_report.dart';

/// `inspectra config fetch`: downloads the remote bases of the
/// configuration into the cache, so that later runs, `build_runner` and
/// air-gapped machines can use them offline.
final class ConfigFetchCommand extends ConfigToolCommand {
  /// Creates the command.
  ConfigFetchCommand(super.context);

  /// The command name.
  @override
  String get name => 'fetch';

  /// The one line description.
  @override
  String get description =>
      'Download and verify the remote bases the configuration extends, for '
      'offline use and build_runner.';

  /// Reports the bases, which every Inspectra command makes available
  /// before it loads the configuration.
  ///
  /// Returns the report.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async => ConfigFetchReport(
    configBases ??
        const ConfigFetchOutcome(
          stack: ConfigLayerStack(layers: <ConfigLayer>[], starts: <int>[]),
        ),
  );
}
