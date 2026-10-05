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

/// A report whose evaluation may not have run completely.
///
/// The command line writes such a report like any other and then exits with
/// `69`, even with `--exit-zero`: an incomplete verification must never look
/// clean.
abstract interface class IncompleteReport {
  /// Why the evaluation is incomplete, or `null` when it is complete.
  String? get incompleteReason;
}
