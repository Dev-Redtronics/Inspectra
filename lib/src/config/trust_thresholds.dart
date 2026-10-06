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

import 'package:inspectra/src/config/yaml_reader.dart';

/// Thresholds of the pub.dev trust assessment, the `trust:` section of
/// `inspectra.yaml`.
final class TrustThresholds {
  /// Creates trust thresholds with conservative defaults.
  const TrustThresholds({
    this.freshPackageDays = 7,
    this.youngPackageDays = 30,
    this.freshReleaseHours = 24,
    this.minLikes = 5,
    this.minDownloads = 100,
    this.minPointsRatio = 0.5,
  });

  /// Reads the thresholds from the `trust:` section in [yaml].
  ///
  /// Returns the thresholds.
  ///
  /// Throws an `InspectraConfigException` for unknown keys or invalid
  /// values.
  factory TrustThresholds.fromYaml(YamlReader yaml) {
    const defaults = TrustThresholds();
    const int large = 1 << 30;
    final config = TrustThresholds(
      freshPackageDays: yaml.integer(
        'fresh_package_days',
        min: 0,
        max: large,
        fallback: defaults.freshPackageDays,
      ),
      youngPackageDays: yaml.integer(
        'young_package_days',
        min: 0,
        max: large,
        fallback: defaults.youngPackageDays,
      ),
      freshReleaseHours: yaml.integer(
        'fresh_release_hours',
        min: 0,
        max: large,
        fallback: defaults.freshReleaseHours,
      ),
      minLikes: yaml.integer(
        'min_likes',
        min: 0,
        max: large,
        fallback: defaults.minLikes,
      ),
      minDownloads: yaml.integer(
        'min_downloads',
        min: 0,
        max: large,
        fallback: defaults.minDownloads,
      ),
      minPointsRatio: yaml.number(
        'min_points_ratio',
        min: 0,
        max: 1,
        fallback: defaults.minPointsRatio,
      ),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// A package first published less than this many days ago is CRITICAL.
  final int freshPackageDays;

  /// A package first published less than this many days ago is MEDIUM.
  final int youngPackageDays;

  /// A version published less than this many hours ago is CRITICAL.
  final int freshReleaseHours;

  /// Fewer likes than this is reported as low endorsement.
  final int minLikes;

  /// Fewer downloads in 30 days than this is reported as low usage.
  final int minDownloads;

  /// A pub points ratio below this is reported as low quality.
  final double minPointsRatio;
}
