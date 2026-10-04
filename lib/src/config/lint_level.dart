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

/// The lowest severity of a `dart analyze` diagnostic that fails the check.
enum LintLevel {
  /// Only errors fail.
  error,

  /// Errors and warnings fail.
  warning,

  /// Errors, warnings and infos - including every lint - fail, like
  /// `dart analyze --fatal-infos`.
  info,

  /// Nothing fails; diagnostics are only reported.
  none,
}
