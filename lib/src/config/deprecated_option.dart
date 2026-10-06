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

import 'package:inspectra/src/config/config_deprecation.dart';

/// A place in a configuration file that still uses the old name of a
/// renamed option.
final class DeprecatedOption {
  /// Creates the use of [deprecation] at the dotted [path], as written in
  /// the [file] (`null` for the project's own configuration) at [line].
  const DeprecatedOption({
    required this.deprecation,
    required this.path,
    this.file,
    this.line,
  });

  /// The rename.
  final ConfigDeprecation deprecation;

  /// The dotted path of the old name as written, such as
  /// `inspectra.trivy.secrets` in `pubspec.yaml`.
  final String path;

  /// The base the old name is written in, or `null` for the project's own
  /// configuration.
  final String? file;

  /// The line of the old name, if known.
  final int? line;

  /// Describes the use for a warning.
  ///
  /// Returns a text such as `"trivy.secrets" is deprecated since 1.1.0;
  /// use "trivy.secret".`.
  String describe() {
    final where = file == null ? '' : ' in $file';
    final note = deprecation.note.isEmpty ? '' : ' ${deprecation.note}';
    return '"$path"$where is deprecated since ${deprecation.since}; use '
        '"${deprecation.newKey}" instead, or run "inspectra config migrate".'
        '$note';
  }
}
