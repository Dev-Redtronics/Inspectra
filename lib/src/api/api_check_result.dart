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

/// The outcome of comparing the public API with its committed dump.
class ApiCheckResult {
  /// Creates the outcome.
  const ApiCheckResult({
    required this.dumpPath,
    required this.diff,
    required this.missing,
  });

  /// The dump file, relative to the package root.
  final String dumpPath;

  /// How the API differs from the dump, or `null` when it matches.
  final String? diff;

  /// Whether no dump has been recorded yet.
  final bool missing;

  /// Whether the check failed.
  bool get failed => missing || diff != null;

  /// A readable summary for the console.
  String render() {
    if (missing) {
      return 'No public API dump has been recorded yet at $dumpPath.\n\n'
          'Create it and commit the result:\n\n'
          '    dart run inspectra api dump';
    }
    if (diff == null) {
      return 'The public API matches $dumpPath.';
    }
    return 'The public API changed.\n\n$diff\n\n'
        'If the change is intended, record it and commit the result:\n\n'
        '    dart run inspectra api dump';
  }
}
