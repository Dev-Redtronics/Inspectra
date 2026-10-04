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

import 'package:pub_semver/pub_semver.dart';

/// How far a release moves the version, derived from its commits as
/// [Semantic Versioning](https://semver.org/) prescribes.
///
/// Before `1.0.0` the public API is not considered stable and Dart's
/// convention applies: a breaking change raises the minor version and
/// everything else the patch version.
enum VersionBump {
  /// Bug fixes and other compatible changes.
  patch('patch'),

  /// New, backwards compatible functionality.
  minor('minor'),

  /// Breaking changes.
  major('major');

  /// Creates a bump with its report [id].
  const VersionBump(this.id);

  /// The name used in reports.
  final String id;

  /// Applies the bump to the released version [current].
  ///
  /// A pre-release such as `2.0.0-beta.1` is followed by its release when
  /// the release is large enough for the bump.
  ///
  /// Returns the next version.
  Version apply(Version current) {
    final unstable = current.major == 0;
    return switch (this) {
      VersionBump.major => unstable ? current.nextMinor : current.nextMajor,
      VersionBump.minor => unstable ? current.nextPatch : current.nextMinor,
      VersionBump.patch => current.nextPatch,
    };
  }
}
