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

/// The pub.dev score of a package.
final class PubScore {
  /// Creates a score record.
  const PubScore({
    this.grantedPoints,
    this.maxPoints,
    this.likeCount,
    this.downloadCount30Days,
  });

  /// The pub points granted by the analysis.
  final int? grantedPoints;

  /// The maximum achievable pub points.
  final int? maxPoints;

  /// The number of likes.
  final int? likeCount;

  /// The number of downloads in the last 30 days.
  final int? downloadCount30Days;
}
