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

import 'package:inspectra/src/config/scan_config.dart';

/// Settings of a scan that `build_runner` can run as well.
abstract base class BuildScanConfig extends ScanConfig {
  /// Creates the settings.
  const BuildScanConfig({
    required super.enabled,
    required this.runOnBuild,
    required super.failOnFindings,
    required super.severity,
  });

  /// Whether `dart run build_runner build` runs this scan too.
  ///
  /// Only the secret scan does by default: it reads files that are already
  /// on disk and costs a second. The vulnerability scan downloads Trivy's
  /// database, and the license scan reads the license file of every
  /// dependency, so both run from the command line or in CI unless enabled
  /// here.
  final bool runOnBuild;
}
