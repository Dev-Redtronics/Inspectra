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

/// The kinds of project `config init` writes a starting configuration for.
enum ConfigPreset {
  /// An application or internal package that is never published: format,
  /// lint, style, coverage, Trivy and a dependency policy that keeps it
  /// off pub.dev.
  app('app'),

  /// A package published to a registry: the [app] checks plus the public
  /// API dump with semantic versioning, the changelog and the metadata
  /// pub.dev shows.
  library('library'),

  /// A Flutter plugin: the [library] checks with the Flutter test runner.
  plugin('plugin'),

  /// The [app] or [library] checks made strict for organisations: Trivy
  /// required, checksums and imports checked, a baseline that never covers
  /// HIGH or CRITICAL, and `local` and `ci` profiles.
  enterprise('enterprise');

  /// Creates the preset spelled [id] on the command line.
  const ConfigPreset(this.id);

  /// The spelling on the command line.
  final String id;
}
