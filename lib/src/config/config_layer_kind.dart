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

/// Where a layer of the configuration comes from.
enum ConfigLayerKind {
  /// The configuration of the project itself: `inspectra.yaml`, the file
  /// named by `--config` or the `inspectra:` section of `pubspec.yaml`.
  project('project'),

  /// A base file named by a relative path.
  file('file'),

  /// A base file of a package, named as `package:name/path.yaml`.
  package('package'),

  /// A base downloaded from an `https` URL and verified by its SHA-256.
  remote('remote');

  /// Creates the kind spelled [id] in reports.
  const ConfigLayerKind(this.id);

  /// The spelling in the JSON report of `config show`.
  final String id;
}
