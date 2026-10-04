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

/// The normalised severity scale shared by every Inspectra scanner.
///
/// Every finding, regardless of whether it originates from OSV.dev, Trivy or
/// one of the static source scanners, is mapped onto this five step scale so
/// that thresholds such as `--fail-on` and `--min-severity` behave identically
/// across all commands.
///
/// The declaration order is significant: it runs from the most to the least
/// severe level and [rank] is derived from it.
enum Severity {
  /// An issue that must be fixed immediately, for example remote code
  /// execution or an actively exploited vulnerability.
  critical('CRITICAL'),

  /// A serious issue that should be fixed before the next release.
  high('HIGH'),

  /// An issue of moderate impact that should be scheduled for fixing.
  medium('MEDIUM'),

  /// An issue of limited impact.
  low('LOW'),

  /// An issue whose severity could not be determined from the data source.
  ///
  /// It is deliberately ranked below [low] so that `--min-severity low` hides
  /// it while the default threshold still reports it.
  unknown('UNKNOWN');

  /// Creates a severity with its canonical upper case [label].
  const Severity(this.label);

  /// The canonical upper case label, for example `CRITICAL`.
  ///
  /// This is the spelling used in text reports, JSON documents and the
  /// configuration file.
  final String label;

  /// Lookup table from every accepted spelling to its severity.
  ///
  /// `MODERATE` is the GitHub Security Advisory spelling of [medium] and
  /// `NONE` is the CVSS spelling of a zero score, which Inspectra reports as
  /// [low] so that it is never silently dropped.
  static const Map<String, Severity> _aliases = <String, Severity>{
    'CRITICAL': Severity.critical,
    'HIGH': Severity.high,
    'MEDIUM': Severity.medium,
    'MODERATE': Severity.medium,
    'LOW': Severity.low,
    'NONE': Severity.low,
    'UNKNOWN': Severity.unknown,
  };

  /// The position of this severity on the scale, `0` being the most severe.
  int get rank => index;

  /// Whether this severity is at least as severe as [threshold].
  ///
  /// For example `Severity.high.isAtLeast(Severity.medium)` is `true` while
  /// `Severity.low.isAtLeast(Severity.medium)` is `false`. Every severity is
  /// at least [unknown], which makes [unknown] the "report everything"
  /// threshold.
  ///
  /// Returns `true` when this severity reaches the [threshold].
  bool isAtLeast(Severity threshold) => rank <= threshold.rank;

  /// Parses a severity [value] case-insensitively.
  ///
  /// Accepts every canonical [label] plus the aliases `MODERATE` and `NONE`.
  /// Anything else, including `null` and blank strings, yields [unknown] so
  /// that malformed data from a remote source never aborts a scan.
  ///
  /// Returns the parsed severity or [unknown].
  static Severity parse(String? value) {
    final normalised = value?.trim().toUpperCase() ?? '';
    return _aliases[normalised] ?? Severity.unknown;
  }

  /// Parses a user supplied severity [value] strictly.
  ///
  /// Unlike [parse] this returns `null` for anything that is not a canonical
  /// label in lower or upper case, which lets callers turn a typo in a
  /// command line flag or configuration file into a precise error message.
  ///
  /// Returns the parsed severity, or `null` when [value] is not recognised.
  static Severity? tryParseStrict(String value) {
    final normalised = value.trim().toUpperCase();
    final matches = Severity.values.where((s) => s.label == normalised);
    return matches.firstOrNull;
  }

  /// Maps a CVSS base [score] between `0.0` and `10.0` to a severity.
  ///
  /// The thresholds follow the qualitative rating scale of the CVSS v3.1
  /// specification: `9.0` and above is [critical], `7.0` and above is [high],
  /// `4.0` and above is [medium] and everything else is [low].
  ///
  /// Returns the severity matching the score.
  static Severity fromCvssScore(double score) {
    if (score >= 9.0) {
      return Severity.critical;
    }
    if (score >= 7.0) {
      return Severity.high;
    }
    if (score >= 4.0) {
      return Severity.medium;
    }
    return Severity.low;
  }
}
