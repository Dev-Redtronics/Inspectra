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

import 'package:inspectra/src/config/inspectra_config.dart';

/// The scans that can be selected by name.
enum TrivyScan {
  /// Credentials in sources and configuration files.
  secret,

  /// Licenses of dependencies.
  license,

  /// Known vulnerabilities of dependencies.
  vulnerability,

  /// A plain `trivy fs` of the package.
  filesystem;

  /// Whether this scan is enabled in [config].
  bool isEnabled(TrivyConfig config) => switch (this) {
    secret => config.secret.enabled,
    license => config.license.enabled,
    vulnerability => config.vulnerability.enabled,
    filesystem => config.filesystem.enabled,
  };
}
