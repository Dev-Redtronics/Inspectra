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

import 'dart:math';

import '../archive/archive_entry.dart';
import '../archive/archive_entry_filter.dart';
import '../model/finding.dart';
import '../model/finding_source.dart';
import '../model/severity.dart';
import '../model/source_location.dart';
import '../report/snippet_sanitizer.dart';
import 'dart_literal_tokenizer.dart';

/// Flags string literals whose Shannon entropy suggests an encrypted or
/// encoded payload or an embedded secret.
///
/// Entropy is measured in bits per character over the Unicode code points of
/// each literal. Because a string of `n` characters can reach at most
/// `log2(n)` bits, short strings can never exceed the thresholds: the medium
/// threshold needs at least 23 characters, the high threshold at least 46.
/// Generated sources, whose literals are often hashes, are skipped.
final class EntropyScanner {
  /// Creates a scanner skipping files that end with one of
  /// [excludedSuffixes] or lie in one of [excludedDirectories].
  const EntropyScanner({
    required this.excludedSuffixes,
    this.excludedDirectories = const <String>[],
  });

  /// The entropy above which a literal is reported as MEDIUM.
  static const double mediumThreshold = 4.5;

  /// The entropy above which a literal is reported as HIGH.
  static const double highThreshold = 5.5;

  /// The minimum literal length considered.
  static const int minLength = 20;

  /// File name suffixes that are not scanned.
  final List<String> excludedSuffixes;

  /// Top level directories that are not scanned.
  final List<String> excludedDirectories;

  /// The length of an ascending character run, such as `abcdef` or
  /// `012345`, that marks a character table rather than a payload.
  static const int _alphabetRun = 6;

  /// Scans the Dart files of [entries].
  ///
  /// Returns the findings, HIGH before MEDIUM, then by file and line.
  List<Finding> scan(List<ArchiveEntry> entries) {
    final findings = <Finding>[];
    final candidates = entries.where(
      (entry) =>
          entry.isText &&
          entry.path.endsWith('.dart') &&
          !excludedSuffixes.any(entry.path.endsWith) &&
          !isInExcludedDirectory(entry, excludedDirectories),
    );
    for (final entry in candidates) {
      final literals = DartLiteralTokenizer(entry.text).extract();
      for (final literal in literals) {
        final finding = _evaluate(entry, literal.value, literal.line);
        if (finding != null) {
          findings.add(finding);
        }
      }
    }
    return findings..sort((a, b) => a.severity.rank.compareTo(b.severity.rank));
  }

  /// Computes the Shannon entropy of [text] in bits per code point.
  ///
  /// Returns `0` for empty text.
  static double shannonEntropy(String text) {
    final runes = text.runes.toList();
    if (runes.isEmpty) {
      return 0;
    }
    final counts = <int, int>{};
    for (final rune in runes) {
      counts[rune] = (counts[rune] ?? 0) + 1;
    }
    var entropy = 0.0;
    for (final count in counts.values) {
      final probability = count / runes.length;
      entropy -= probability * log(probability) / ln2;
    }
    return entropy;
  }

  /// Whether [value] is high in entropy but benign: prose and headers
  /// contain whitespace, which encoded payloads and keys do not, and
  /// character tables contain ascending runs such as `abcdef`.
  ///
  /// Returns `true` for benign literals.
  static bool _isBenign(String value) {
    if (RegExp(r'\s').hasMatch(value)) {
      return true;
    }
    final units = value.codeUnits;
    var run = 1;
    for (var index = 1; index < units.length; index++) {
      run = units[index] == units[index - 1] + 1 ? run + 1 : 1;
      if (run >= _alphabetRun) {
        return true;
      }
    }
    return false;
  }

  /// Evaluates one literal [value] of [entry] at [line].
  ///
  /// Returns a finding when the entropy exceeds the medium threshold.
  Finding? _evaluate(ArchiveEntry entry, String value, int line) {
    if (value.runes.length < minLength || _isBenign(value)) {
      return null;
    }
    final entropy = shannonEntropy(value);
    if (entropy <= mediumThreshold) {
      return null;
    }
    final severity = entropy > highThreshold ? Severity.high : Severity.medium;
    final rounded = (entropy * 100).round() / 100;
    final excerpt = value.length > 60 ? value.substring(0, 60) : value;
    return Finding(
      ruleId: 'HIGH_ENTROPY_STRING',
      source: FindingSource.entropy,
      severity: severity,
      title: 'High-entropy string literal (possible obfuscation/encryption)',
      description: 'Entropy: ${rounded.toStringAsFixed(2)} bits per char',
      location: SourceLocation(entry.path, line: line),
      snippet: SnippetSanitizer.sanitize(excerpt),
      attributes: <String, Object?>{'entropy': rounded},
    );
  }
}
