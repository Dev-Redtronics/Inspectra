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

/// One top-level declaration of a public library in an API dump: a type
/// with its members, or a single function, variable, accessor or typedef.
final class ApiDeclaration {
  /// Creates the declaration [name]d in the dump, written as [line]; a
  /// type has its [members] by name and, for an enum, its [values].
  const ApiDeclaration({
    required this.name,
    required this.line,
    this.isType = false,
    this.members = const <String, String>{},
    this.values = const <String>[],
  });

  /// The name that identifies the declaration, such as `Shape`,
  /// `get label` or `operator ==`.
  final String name;

  /// The single line of a function or variable, or the header of a type
  /// without its opening brace.
  final String line;

  /// Whether the declaration is a class, mixin, enum or extension.
  final bool isType;

  /// The member lines of a type by their name.
  final Map<String, String> members;

  /// The values of an enum, in declaration order.
  final List<String> values;
}
