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

/// Where the Trivy executable used for a scan came from.
enum TrivyOrigin {
  /// The executable configured with `trivy.executable`.
  configured('configured'),

  /// An executable found on the `PATH` or in a well-known directory.
  installed('installed'),

  /// A binary downloaded earlier and found in Inspectra's cache.
  cached('cached'),

  /// A binary downloaded during this run.
  downloaded('downloaded');

  /// Creates an origin with its report spelling [id].
  const TrivyOrigin(this.id);

  /// The spelling used in reports.
  final String id;
}
