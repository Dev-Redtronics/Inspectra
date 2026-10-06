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

/// An option that was renamed within its section. Files may keep the old
/// name until the next major version: the value is read under the new
/// name, every command warns, `config lint` reports
/// `CONFIG_DEPRECATED_OPTION` and `config migrate` rewrites the file.
final class ConfigDeprecation {
  /// Creates the rename of the dotted [oldPath] to [newPath] in the
  /// version [since], with a [note] for people.
  ///
  /// Both paths name the same section; only the last key differs.
  const ConfigDeprecation({
    required this.oldPath,
    required this.newPath,
    required this.since,
    this.note = '',
  });

  /// The dotted path of the old name, such as `trivy.secrets`.
  final String oldPath;

  /// The dotted path of the new name, such as `trivy.secret`.
  final String newPath;

  /// The version that introduced the new name.
  final String since;

  /// Why the option was renamed, or an empty text.
  final String note;

  /// The dotted path of the section both names belong to, empty for the
  /// top level.
  String get section {
    final int dot = newPath.lastIndexOf('.');
    return dot < 0 ? '' : newPath.substring(0, dot);
  }

  /// The old name within its section.
  String get oldKey => oldPath.substring(oldPath.lastIndexOf('.') + 1);

  /// The new name within its section.
  String get newKey => newPath.substring(newPath.lastIndexOf('.') + 1);
}

/// Every renamed option, from the oldest to the newest rename.
const configDeprecations = <ConfigDeprecation>[];
