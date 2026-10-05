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

import 'package:inspectra/src/config/config_origin.dart';

/// The value of a configuration option given outside of the configuration
/// file, with where it came from.
final class ConfigOverride {
  /// Creates an override of the raw text [value] from [origin]; [variable]
  /// names the environment variable of an environment override.
  const ConfigOverride({
    required this.value,
    required this.origin,
    this.variable,
  });

  /// The raw text of the override.
  final String value;

  /// [ConfigOrigin.commandLine] or [ConfigOrigin.environment].
  final ConfigOrigin origin;

  /// The environment variable, for an environment override.
  final String? variable;

  /// Returns a description of the origin for error messages, such as
  /// `the environment variable INSPECTRA_TRIVY_VERSION`.
  String describe() => switch (origin) {
    ConfigOrigin.commandLine => 'the command line',
    ConfigOrigin.environment => 'the environment variable $variable',
    ConfigOrigin.file => 'the configuration file',
    ConfigOrigin.defaults => 'the default',
  };
}
