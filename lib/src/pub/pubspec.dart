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

import 'package:inspectra/src/pub/dependency_spec.dart';

/// The parts of a `pubspec.yaml` file that Inspectra analyses.
final class Pubspec {
  /// Creates a parsed pubspec read from [path].
  const Pubspec({
    required this.path,
    this.name,
    this.dependencies = const <String, DependencySpec>{},
    this.devDependencies = const <String, DependencySpec>{},
    this.dependencyOverrides = const <String, DependencySpec>{},
    this.sdkConstraint,
    this.flutterConstraint,
  });

  /// The file the pubspec was read from.
  final String path;

  /// The package name, if declared.
  final String? name;

  /// The `dependencies` section.
  final Map<String, DependencySpec> dependencies;

  /// The `dev_dependencies` section.
  final Map<String, DependencySpec> devDependencies;

  /// The `dependency_overrides` section.
  final Map<String, DependencySpec> dependencyOverrides;

  /// The `environment.sdk` constraint.
  final String? sdkConstraint;

  /// The `environment.flutter` constraint.
  final String? flutterConstraint;

  /// The names of all direct and development dependencies.
  List<String> get declaredNames => <String>[
    ...dependencies.keys,
    ...devDependencies.keys,
  ];

  /// Whether this is a Flutter project, which decides between
  /// `flutter pub add` and `dart pub add`.
  ///
  /// A project is a Flutter project when it depends on the Flutter SDK in
  /// either dependency section or declares an `environment.flutter`
  /// constraint.
  bool get isFlutterProject {
    final bool flutterSdk = <DependencySpec?>[
      dependencies['flutter'],
      devDependencies['flutter'],
    ].any((spec) => spec?.sdk == 'flutter');
    return flutterSdk || flutterConstraint != null;
  }
}
