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

/// Where the effective value of a configuration option comes from, in
/// increasing order of precedence.
enum ConfigOrigin {
  /// The built-in default; nothing configures the option.
  defaults('default'),

  /// The configuration file: `inspectra.yaml`, the file named by `--config`
  /// or `INSPECTRA_CONFIG`, or the `inspectra:` section of `pubspec.yaml`.
  file('file'),

  /// An environment variable, such as `INSPECTRA_TRIVY_VERSION`.
  environment('environment'),

  /// The command line: `--set key=value` or a dedicated flag.
  commandLine('commandLine');

  /// Creates an origin with its stable [id].
  const ConfigOrigin(this.id);

  /// The name of the origin in JSON reports.
  final String id;
}
