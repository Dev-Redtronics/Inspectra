/*
 * Copyright 2026 Redtronics
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

import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:pub_semver/pub_semver.dart';

/// Validates package names and versions before they are used in URLs or
/// commands.
///
/// Validation prevents a crafted argument from being interpolated into a
/// request path or a `pub add` command line.
final class PackageName {
  /// Prevents instantiation; this type only offers static helpers.
  const PackageName._();

  /// The grammar of valid Dart package names.
  static final _pattern = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

  /// Ensures [name] is a syntactically valid package name.
  ///
  /// Returns [name].
  ///
  /// Throws an [InvalidUsageException] for invalid names.
  static String validate(String name) {
    if (!_pattern.hasMatch(name)) {
      throw InvalidUsageException('"$name" is not a valid Dart package name.');
    }
    return name;
  }

  /// Ensures [version] is an exact semantic version such as `1.2.3` or
  /// `2.0.0-dev.1`, not a constraint such as `^1.2.0`.
  ///
  /// Returns [version].
  ///
  /// Throws an [InvalidUsageException] for constraints or malformed versions.
  static String validateExactVersion(String version) {
    try {
      Version.parse(version);
    } on FormatException {
      throw InvalidUsageException(
        '"$version" is not an exact version. Use a version such as 1.2.3 so '
        'that the audited source matches the installed package.',
      );
    }
    return version;
  }
}
