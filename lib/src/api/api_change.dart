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

import 'package:inspectra/src/api/api_change_kind.dart';

/// One difference between two versions of a public API, with whether and
/// why it breaks consumers.
final class ApiChange {
  /// Creates the change of [kind] to the [declaration] in [library], or to
  /// its [member], explained by [reason]; [before] and [after] are the
  /// lines of the dump, where they exist.
  const ApiChange({
    required this.kind,
    required this.library,
    required this.declaration,
    required this.reason,
    this.member,
    this.before,
    this.after,
  });

  /// Whether the change breaks consumers.
  final ApiChangeKind kind;

  /// The URI of the library, such as `package:shapes/shapes.dart`.
  final String library;

  /// The name of the top-level declaration, or empty for the library
  /// itself.
  final String declaration;

  /// The name of the changed member, if the change is inside a type.
  final String? member;

  /// Why the change is breaking or additive.
  final String reason;

  /// The line before the change, if there was one.
  final String? before;

  /// The line after the change, if there is one.
  final String? after;

  /// The changed element, such as `Shape.area` or `circle`.
  String get subject {
    final String? name = member;
    if (declaration.isEmpty) {
      return library;
    }
    return name == null ? declaration : '$declaration.$name';
  }

  /// Serializes the change.
  ///
  /// Returns the JSON object.
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.id,
    'library': library,
    'declaration': declaration,
    'member': ?member,
    'reason': reason,
    'before': ?before,
    'after': ?after,
  };
}
