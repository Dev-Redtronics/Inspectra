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

import 'package:inspectra/src/api/api_change.dart';
import 'package:inspectra/src/api/api_change_kind.dart';
import 'package:inspectra/src/changelog/version_bump.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/model/source_location.dart';
import 'package:pub_semver/pub_semver.dart';

/// The outcome of comparing the public API with the last release: every
/// change, the version the changes require and whether `pubspec.yaml`
/// declares at least that version.
final class SemverResult {
  /// Creates the result of comparing the API with the release [baseline]
  /// of version [baselineVersion]; [version] is the version in
  /// `pubspec.yaml`, [changes] are the differences and [undeclaredBreaking]
  /// tells that no commit since the release announces a breaking change.
  const SemverResult({
    required this.baseline,
    required this.baselineVersion,
    required this.version,
    required this.changes,
    this.undeclaredBreaking = false,
    this.dumpPath = '',
  }) : skipped = null;

  /// Creates the result of a comparison that did not run, because of
  /// [skipped].
  const SemverResult.skipped(String this.skipped, {this.dumpPath = ''})
    : baseline = null,
      baselineVersion = null,
      version = null,
      changes = const <ApiChange>[],
      undeclaredBreaking = false;

  /// The release tag or revision the API was compared with, or `null` when
  /// the comparison was skipped.
  final String? baseline;

  /// The version of [baseline], or `null` when it names none.
  final Version? baselineVersion;

  /// The version `pubspec.yaml` declares.
  final Version? version;

  /// Every difference of the public API since [baseline].
  final List<ApiChange> changes;

  /// Whether the API breaks consumers but no commit since [baseline] is
  /// marked as a breaking change.
  final bool undeclaredBreaking;

  /// The API dump, relative to the package, for findings.
  final String dumpPath;

  /// Why the comparison did not run, or `null` when it ran.
  final String? skipped;

  /// The changes that break consumers.
  List<ApiChange> get breaking =>
      changes.where((change) => change.kind == ApiChangeKind.breaking).toList();

  /// The changes that consumers can adopt without changes.
  List<ApiChange> get additive =>
      changes.where((change) => change.kind == ApiChangeKind.additive).toList();

  /// The version step the changes require: major for breaking changes,
  /// minor for additions, or `null` without changes.
  VersionBump? get bump {
    if (breaking.isNotEmpty) {
      return VersionBump.major;
    }
    return additive.isNotEmpty ? VersionBump.minor : null;
  }

  /// The lowest version the changes allow, or `null` when nothing is
  /// required; before 1.0.0 a breaking change needs a minor version.
  Version? get required {
    final VersionBump? step = bump;
    final Version? base = baselineVersion;
    return step == null || base == null ? null : step.apply(base);
  }

  /// Whether `pubspec.yaml` declares a lower version than [required]; a
  /// pre-release counts as the release it leads to.
  bool get violated {
    final Version? minimum = required;
    final Version? current = version;
    if (minimum == null || current == null) {
      return false;
    }
    return Version(current.major, current.minor, current.patch) < minimum;
  }

  /// Whether the check failed: the version is too low, or a breaking
  /// change is not announced by any commit.
  bool get failed => violated || undeclaredBreaking;

  /// The findings of the check.
  List<Finding> get findings => <Finding>[
    if (violated)
      Finding(
        ruleId: 'SEMVER_VIOLATION',
        source: FindingSource.quality,
        severity: Severity.high,
        title:
            'Version $version is too low for the API changes since '
            '$baseline',
        description:
            'The public API has ${breaking.length} breaking and '
            '${additive.length} additive change(s) since $baseline; set the '
            'version to $required or higher.',
        location: const SourceLocation('pubspec.yaml'),
        attributes: const <String, Object?>{'check': 'semver'},
      ),
    if (undeclaredBreaking)
      Finding(
        ruleId: 'SEMVER_UNDECLARED_BREAKING',
        source: FindingSource.quality,
        severity: Severity.medium,
        title: 'A breaking API change is not announced by any commit',
        description:
            'The public API breaks consumers, but no commit since $baseline '
            'is marked with "!" or a BREAKING CHANGE footer, so the '
            'changelog does not mention it.',
        location: SourceLocation(dumpPath),
        attributes: const <String, Object?>{'check': 'semver'},
      ),
  ];

  /// Describes the result for the console.
  ///
  /// Returns the text.
  String render() {
    final String? reason = skipped;
    if (reason != null) {
      return 'API semver: skipped, $reason';
    }
    final since = baselineVersion == null
        ? '$baseline'
        : '$baseline ($baselineVersion)';
    final lines = <String>[
      'API semver: ${changes.length} change(s) since $since.',
      for (final ApiChange change in breaking)
        '  - breaking  ${change.subject}: ${change.reason}',
      for (final ApiChange change in additive)
        '  + additive  ${change.subject}: ${change.reason}',
    ];
    final Version? minimum = required;
    lines.add(
      minimum == null
          ? 'No version is required; pubspec.yaml declares $version.'
          : '${bump?.id} change: version $minimum or higher is required; '
                'pubspec.yaml declares $version'
                '${violated ? ', which is too low.' : '.'}',
    );
    if (undeclaredBreaking) {
      lines.add(
        'No commit since $baseline is marked as a breaking change (! or '
        'BREAKING CHANGE).',
      );
    }
    return lines.join('\n');
  }

  /// Serializes the result.
  ///
  /// Returns the JSON object.
  Map<String, Object?> toJson() => <String, Object?>{
    'check': 'semver',
    'failed': failed,
    'skipped': ?skipped,
    'baseline': ?baseline,
    'baselineVersion': ?baselineVersion?.toString(),
    'version': ?version?.toString(),
    'bump': ?bump?.id,
    'required': ?required?.toString(),
    'undeclaredBreaking': undeclaredBreaking,
    'changes': <Map<String, Object?>>[
      for (final ApiChange change in changes) change.toJson(),
    ],
  };
}
