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

/// The outcome of one section of a report.
enum SectionStatus {
  /// The evaluation ran and passed.
  passed('passed'),

  /// The evaluation ran and failed.
  failed('failed'),

  /// The evaluation did not run, because it is not enabled or was skipped.
  skipped('skipped'),

  /// The evaluation could not run completely, so its result is unknown.
  error('error');

  /// Creates a status with its stable [id].
  const SectionStatus(this.id);

  /// The name of the status in JSON reports.
  final String id;

  /// Looks up the status named [id].
  ///
  /// Returns the status, or `null` when [id] names none.
  static SectionStatus? tryParse(String id) =>
      values.where((status) => status.id == id).firstOrNull;
}
