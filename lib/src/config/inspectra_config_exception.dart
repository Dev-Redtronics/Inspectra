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

/// A configuration value that is missing, unknown or of the wrong type.
///
/// It names the dotted path of the offending key, for example
/// `trivy.secret.severity[1]`, so that the user can find it in
/// `inspectra.yaml`, the `inspectra:` section of `pubspec.yaml`, an
/// `INSPECTRA_*` environment variable or a command line override. It maps to
/// exit code `65`.
final class InspectraConfigException implements Exception {
  /// Creates an exception for the key at [path] described by [message];
  /// [file] names the base the key was read from, if it is not the
  /// project's own configuration.
  const InspectraConfigException(this.path, this.message, {this.file});

  /// The dotted path of the offending key.
  final String path;

  /// What is wrong with the value at [path].
  final String message;

  /// The base of the configuration the key was read from, such as
  /// `package:acme_policy/inspectra.yaml`, or `null` for the project's own
  /// configuration.
  final String? file;

  /// Returns the complete, user facing description.
  @override
  String toString() {
    final String? base = file;
    final where = base == null ? '"$path"' : '"$path" in $base';
    return 'Invalid Inspectra configuration at $where: $message';
  }
}
