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

/// Whether and how strictly Trivy takes part in a scan.
enum TrivyMode {
  /// Trivy is used when it is installed or can be downloaded. When neither
  /// is possible a warning is printed and the remaining scanners still run.
  auto('auto'),

  /// Trivy must run. When it is neither installed nor downloadable the scan
  /// fails with exit code `69`, so a CI pipeline cannot silently lose it.
  required('required'),

  /// Trivy is never located, downloaded or executed.
  disabled('disabled');

  /// Creates a mode with its configuration file spelling [id].
  const TrivyMode(this.id);

  /// The spelling used in `inspectra.yaml` and on the command line.
  final String id;
}
