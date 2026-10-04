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
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/model/source_location.dart';
import 'package:inspectra/src/typosquat/levenshtein.dart';
import 'package:inspectra/src/typosquat/popular_packages.dart';

/// Detects dependency names that imitate popular packages.
///
/// Rules (identifiers as in `dart_audit`):
///
/// * `LEVENSHTEIN_1` (CRITICAL): one edit away from a popular package;
/// * `LEVENSHTEIN_2` (HIGH): two edits away;
/// * `PREFIX_FLUTTER`, `SUFFIX_FLUTTER`, `PREFIX_DART_PUB` (HIGH): a popular
///   name wrapped in an official sounding prefix or suffix;
/// * `SUSPICIOUS_SUFFIX` (MEDIUM): a popular name with a short unusual
///   suffix.
///
/// Explicit extensions of a popular name (an affix or a separated suffix)
/// are classified as such before edit distances are considered.
///
/// Improvements over `dart_audit`: the closest popular package is reported
/// instead of the first one within reach, names that are popular themselves
/// are never reported, at most one finding per name is produced, and an
/// allow list removes known false positives.
final class TyposquatDetector {
  /// Creates a detector protecting the built-in popular packages plus
  /// [extraPopular] and never reporting names in [allow].
  TyposquatDetector({
    List<String> extraPopular = const <String>[],
    List<String> allow = const <String>[],
  }) : _popular = <String>{...PopularPackages.names, ...extraPopular},
       _allow = allow.toSet();

  /// The popular names to protect.
  final Set<String> _popular;

  /// Names that are never reported.
  final Set<String> _allow;

  /// Suffixes that legitimately extend popular package names.
  static const _commonSuffixes = <String>{
    'core',
    'lite',
    'plus',
    'pro',
    'extra',
    'utils',
    'util',
    'helpers',
    'helper',
    'extensions',
    'ext',
    'plugin',
    'adapter',
    'test',
    'web',
    'dev',
    'lint',
    'gen',
    'ios',
    'android',
    'macos',
    'linux',
    'windows',
    'ui',
    'annotation',
    'generator',
    'platform_interface',
    'flutter',
    'mock',
  };

  /// The affix rules: pattern, rule id and description.
  static final _affixes = <(RegExp, String, String)>[
    (
      RegExp('^flutter[_-]'),
      'PREFIX_FLUTTER',
      'Adds "flutter_" prefix — common confusion attack',
    ),
    (
      RegExp(r'[_-]flutter$'),
      'SUFFIX_FLUTTER',
      'Adds "_flutter" suffix — common confusion attack',
    ),
    (
      RegExp('^(?:dart|pub)[_-]'),
      'PREFIX_DART_PUB',
      'Adds "dart_" or "pub_" prefix — confusion with official packages',
    ),
  ];

  /// Normalises [name] for comparison: lower case without separators.
  ///
  /// Returns the normalised name.
  static String _normalise(String name) =>
      name.toLowerCase().replaceAll(RegExp('[-_]'), '');

  /// Analyses dependency [names]; [locate] maps a name to its declaration.
  ///
  /// Returns at most one finding per name.
  List<Finding> analyze(
    List<String> names, {
    required SourceLocation Function(String name) locate,
  }) {
    final Set<String> normalisedPopular = _popular.map(_normalise).toSet();
    final findings = <Finding>[];
    for (final name in names) {
      final bool skip =
          _popular.contains(name) ||
          _allow.contains(name) ||
          normalisedPopular.contains(_normalise(name));
      if (skip) {
        continue;
      }
      final Finding? finding =
          _affixMatch(name, locate) ??
          _suffixMatch(name, locate) ??
          _closestMatch(name, locate);
      if (finding != null) {
        findings.add(finding);
      }
    }
    return findings;
  }

  /// Finds the popular package with the smallest edit distance to [name].
  ///
  /// Returns a finding for distance one (names of at least four characters)
  /// or two (at least five characters), otherwise `null`.
  Finding? _closestMatch(
    String name,
    SourceLocation Function(String name) locate,
  ) {
    final String normalised = _normalise(name);
    String? best;
    var bestDistance = 3;
    final List<String> sorted = _popular.toList()..sort();
    for (final candidate in sorted) {
      final int distance = levenshteinDistance(
        normalised,
        _normalise(candidate),
        limit: 2,
      );
      if (distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
      }
    }
    if (best == null) {
      return null;
    }
    if (bestDistance == 1 && normalised.length >= 4) {
      return _finding(
        name,
        'LEVENSHTEIN_1',
        Severity.critical,
        'Package "$name" differs by 1 edit from popular package "$best" — '
            'likely typosquatting',
        best,
        locate,
      );
    }
    if (bestDistance == 2 && normalised.length >= 5) {
      return _finding(
        name,
        'LEVENSHTEIN_2',
        Severity.high,
        'Package "$name" differs by 2 edits from popular package "$best" '
            '— possible typosquatting',
        best,
        locate,
      );
    }
    return null;
  }

  /// Checks whether [name] wraps a popular package in an affix.
  ///
  /// Returns the finding, or `null`.
  Finding? _affixMatch(
    String name,
    SourceLocation Function(String name) locate,
  ) {
    for (final (pattern, rule, description) in _affixes) {
      if (!pattern.hasMatch(name)) {
        continue;
      }
      final String stripped = name.replaceFirst(pattern, '');
      if (_popular.contains(stripped)) {
        return _finding(
          name,
          rule,
          Severity.high,
          '$description — "$name" looks like it wraps "$stripped"',
          stripped,
          locate,
        );
      }
    }
    return null;
  }

  /// Checks whether [name] is a popular package plus a short unusual
  /// suffix.
  ///
  /// Returns the finding for the longest matching popular name, or `null`.
  Finding? _suffixMatch(
    String name,
    SourceLocation Function(String name) locate,
  ) {
    final List<String> candidates =
        _popular
            .where((popular) => name.length > popular.length + 1)
            .where((popular) => name.startsWith(popular))
            .where((popular) => '_-'.contains(name[popular.length]))
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length));
    final String? popular = candidates.firstOrNull;
    if (popular == null) {
      return null;
    }
    final String suffix = name.substring(popular.length + 1);
    if (suffix.length > 4 || _commonSuffixes.contains(suffix)) {
      return null;
    }
    return _finding(
      name,
      'SUSPICIOUS_SUFFIX',
      Severity.medium,
      'Package "$name" appears to be "$popular" with suspicious suffix '
          '"$suffix" — verify this is intentional',
      popular,
      locate,
    );
  }

  /// Creates a typosquat finding.
  ///
  /// Returns the finding.
  Finding _finding(
    String name,
    String rule,
    Severity severity,
    String description,
    String matched,
    SourceLocation Function(String name) locate,
  ) => Finding(
    ruleId: rule,
    source: FindingSource.typosquat,
    severity: severity,
    title: description,
    location: locate(name),
    packageName: name,
    url: 'https://pub.dev/packages/$matched',
    attributes: <String, Object?>{'matchedPublicPackage': matched},
  );
}
