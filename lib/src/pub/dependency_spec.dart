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

import 'package:inspectra/src/pub/dependency_kind.dart';

/// One dependency declaration of a `pubspec.yaml` file.
final class DependencySpec {
  /// Creates a dependency declaration of the given [kind].
  ///
  /// The remaining parameters are only meaningful for some kinds: a version
  /// [constraint] for hosted dependencies (and optionally Git ones),
  /// [hostedUrl] for custom registries, [gitUrl] and [gitRef] for Git,
  /// [path] for path dependencies and [sdk] for SDK dependencies.
  const DependencySpec({
    required this.kind,
    this.constraint,
    this.hostedUrl,
    this.gitUrl,
    this.gitRef,
    this.path,
    this.sdk,
  });

  /// The source kind.
  final DependencyKind kind;

  /// The version constraint as written, or `null` when none was given, which
  /// pub treats like `any`.
  final String? constraint;

  /// The custom registry of a hosted dependency.
  final String? hostedUrl;

  /// The repository URL of a Git dependency.
  final String? gitUrl;

  /// The branch, tag or commit of a Git dependency, or `null` for the
  /// default branch.
  final String? gitRef;

  /// The directory of a path dependency.
  final String? path;

  /// The SDK name of an SDK dependency, for example `flutter`.
  final String? sdk;
}
