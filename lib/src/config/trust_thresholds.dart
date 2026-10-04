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

/// Thresholds of the pub.dev trust assessment, the `trust:` section of
/// `inspectra.yaml`.
final class TrustThresholds {
  /// Creates trust thresholds; the defaults match the rules of `dart_audit`.
  const TrustThresholds({
    this.freshPackageDays = 7,
    this.youngPackageDays = 30,
    this.freshReleaseHours = 24,
    this.minLikes = 5,
    this.minDownloads = 100,
    this.minPointsRatio = 0.5,
  });

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
