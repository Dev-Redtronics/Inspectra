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

import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/io/environment.dart';

/// The configuration values given outside of the configuration file.
///
/// A key such as `trivy.version` is looked up, in order of precedence, in:
///
/// 1. the command line overrides, `--set trivy.version=0.74.0` or a
///    dedicated flag such as `--trivy-version`;
/// 2. the environment variable derived from the key: `INSPECTRA_` followed by
///    the upper case path with dots turned into underscores, here
///    `INSPECTRA_TRIVY_VERSION`.
///
/// Only when neither defines the key is the configuration file consulted.
/// Command line overrides that no option consumed are reported by
/// [ensureAllConsumed], so a typo never goes unnoticed.
final class ConfigOverrides {
  /// Creates overrides from the command line values [cli], keyed by dotted
  /// path, and the [environment].
  ConfigOverrides({
    this.cli = const <String, String>{},
    this.environment = const Environment(<String, String>{}),
  });

  /// Overrides that define nothing.
  factory ConfigOverrides.none() => ConfigOverrides();

  /// The command line values keyed by dotted configuration path.
  final Map<String, String> cli;

  /// The environment providing `INSPECTRA_*` variables.
  final Environment environment;

  /// The command line keys that a configuration option has read.
  final _consumed = <String>{};

  /// Returns the environment variable name of the dotted [path], for example
  /// `INSPECTRA_TRIVY_DOWNLOAD_BASE_URL` for `trivy.download_base_url`.
  static String environmentName(String path) =>
      'INSPECTRA_${path.toUpperCase().replaceAll('.', '_')}';

  /// Looks up the override of the option at the dotted [path].
  ///
  /// Returns the raw text and a description of its origin, or `null` when
  /// the option is not overridden.
  (String, String)? lookup(String path) {
    final String? fromCli = cli[path];
    if (fromCli != null) {
      _consumed.add(path);
      return (fromCli, 'the command line');
    }
    final String variable = environmentName(path);
    final String? fromEnvironment = environment[variable];
    if (fromEnvironment == null) {
      return null;
    }
    return (fromEnvironment, 'the environment variable $variable');
  }

  /// Rejects command line overrides of options that do not exist.
  ///
  /// Throws an [InspectraConfigException] naming the first unknown key.
  void ensureAllConsumed() {
    for (final String key in cli.keys) {
      if (!_consumed.contains(key)) {
        throw InspectraConfigException(
          key,
          'unknown option given on the command line.',
        );
      }
    }
  }
}
