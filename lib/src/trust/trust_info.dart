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

import 'package:inspectra/src/model/finding.dart';

/// The pub.dev trust assessment of one package version.
final class TrustInfo {
  /// Creates a trust assessment.
  const TrustInfo({
    required this.package,
    required this.version,
    required this.latestVersion,
    required this.findings,
    this.createdAt,
    this.publishedAt,
    this.likeCount,
    this.grantedPoints,
    this.maxPoints,
    this.downloadCount30Days,
    this.publisher,
    this.isDiscontinued = false,
    this.replacedBy,
    this.isRetracted = false,
  });

  /// The package name.
  final String package;

  /// The assessed version.
  final String version;

  /// The latest published version.
  final String latestVersion;

  /// The trust findings.
  final List<Finding> findings;

  /// When the first version of the package was published.
  final DateTime? createdAt;

  /// When the assessed version was published.
  final DateTime? publishedAt;

  /// The number of likes.
  final int? likeCount;

  /// The granted pub points.
  final int? grantedPoints;

  /// The maximum pub points.
  final int? maxPoints;

  /// Downloads in the last 30 days.
  final int? downloadCount30Days;

  /// The verified publisher, if any.
  final String? publisher;

  /// Whether the package is discontinued.
  final bool isDiscontinued;

  /// The recommended replacement of a discontinued package.
  final String? replacedBy;

  /// Whether the assessed version was retracted.
  final bool isRetracted;

  /// Whether the package has a verified publisher.
  bool get isVerifiedPublisher => publisher != null;

  /// Serialises the assessment with the field names of `dart_audit`.
  ///
  /// Returns the JSON object.
  Map<String, Object?> toJson() => <String, Object?>{
    'package': package,
    'version': version,
    'latestVersion': latestVersion,
    'createdAt': createdAt?.toIso8601String(),
    'lastPublishedAt': publishedAt?.toIso8601String(),
    'popularityScore': null,
    'likeCount': likeCount,
    'grantedPoints': grantedPoints,
    'maxPoints': maxPoints,
    'publisher': publisher,
    'isVerifiedPublisher': isVerifiedPublisher,
    'downloadCount30Days': downloadCount30Days,
    'isDiscontinued': isDiscontinued,
    'replacedBy': replacedBy,
    'isRetracted': isRetracted,
    'findings': <Object?>[
      for (final finding in findings)
        <String, Object?>{
          'rule': finding.ruleId,
          'severity': finding.severity.label,
          'description': finding.title,
        },
    ],
  };
}
