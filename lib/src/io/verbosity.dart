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

/// How much progress information is written to standard error.
///
/// Reports always go to standard output (or the `--output` file) regardless
/// of the verbosity; it only controls diagnostic chatter.
enum Verbosity {
  /// Only warnings and errors are written.
  quiet,

  /// Progress messages, warnings and errors are written.
  normal,

  /// Additionally writes detailed diagnostics such as resolved tool paths.
  verbose,
}
