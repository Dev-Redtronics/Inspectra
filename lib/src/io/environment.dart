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

import 'dart:io';

/// A read-only view of the process environment variables.
///
/// Every component reads environment variables through this class instead of
/// `Platform.environment`, which allows tests to run against a fully
/// controlled, deterministic environment.
final class Environment {
  /// Creates an environment backed by the given [variables].
  const Environment(this.variables);

  /// Creates an environment backed by the variables of the current process.
  ///
  /// Returns the live process environment.
  factory Environment.current() => Environment(Platform.environment);

  /// The raw variable map.
  final Map<String, String> variables;

  /// Returns the value of the variable called [name], or `null` when it is
  /// not set. Blank values are treated as not set so that `FOO=` behaves like
  /// an absent variable, which is what most users expect.
  String? operator [](String name) {
    final String? value = variables[name];
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value;
  }

  /// The home directory of the current user, taken from `HOME` on POSIX
  /// systems and `USERPROFILE` on Windows, or `null` when neither is set.
  String? get homeDirectory => this['HOME'] ?? this['USERPROFILE'];

  /// Splits the `PATH` variable into its directory entries.
  ///
  /// [separator] is `;` on Windows and `:` everywhere else. Blank entries are
  /// dropped. Windows exposes the variable as `Path`, which is why both
  /// spellings are consulted.
  ///
  /// Returns the directories in search order.
  List<String> pathEntries(String separator) {
    final String raw = this['PATH'] ?? this['Path'] ?? '';
    final List<String> entries = raw.split(separator);
    return entries.where((entry) => entry.trim().isNotEmpty).toList();
  }
}
