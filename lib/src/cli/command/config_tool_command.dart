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
import 'package:inspectra/src/cli/inspectra_command.dart';
import 'package:inspectra/src/cli/shared_options.dart';
import 'package:inspectra/src/config/config_loader.dart';
import 'package:inspectra/src/config/config_overrides.dart';
import 'package:inspectra/src/config/inspectra_config.dart';

/// The common part of `config show`, `config validate` and `config lint`:
/// reading the configuration once more, recording where each value comes
/// from.
abstract class ConfigToolCommand extends InspectraCommand {
  /// Creates the command with the shared and Trivy options, so that it sees
  /// the configuration exactly as `scan` with the same options would.
  ConfigToolCommand(super.context) : super(withTrivyOptions: true);

  /// Reads the configuration of the project with the same configuration
  /// file and overrides as the command line [results] give, recording every
  /// value in [recorder].
  ///
  /// Returns the configuration and the overrides, which know every option
  /// that can be overridden.
  ///
  /// Throws an `InspectraConfigException` for an invalid configuration.
  (InspectraConfig, ConfigOverrides) recordConfig(
    ArgResults results,
    ConfigRecorder recorder,
  ) {
    final overrides = ConfigOverrides(
      cli: SharedOptions.overrides(results),
      environment: context.environment,
    );
    final InspectraConfig config = loadConfig(
      projectDirectory,
      overrides: overrides,
      configFile: results['config'] as String?,
      requirePubspec: false,
      recorder: recorder,
    );
    return (config, overrides);
  }
}
