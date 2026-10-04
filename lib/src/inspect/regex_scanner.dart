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

import 'package:inspectra/src/archive/archive_entry.dart';
import 'package:inspectra/src/archive/archive_entry_filter.dart';
import 'package:inspectra/src/inspect/dart_literal_tokenizer.dart';
import 'package:inspectra/src/inspect/regex_rule.dart';
import 'package:inspectra/src/inspect/regex_rules.dart';
import 'package:inspectra/src/inspect/string_literal.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/source_location.dart';
import 'package:inspectra/src/report/snippet_sanitizer.dart';

/// Matches the [RegexRules] against the files of a package.
///
/// Line rules report at most one finding per rule and line; whole file rules
/// report every non-overlapping match at the line where it starts. Comment
/// lines are skipped for the URL rule because documentation links are not
/// network calls.
final class RegexScanner {
  /// Creates a scanner that additionally trusts [extraTrustedHosts] and
  /// skips files in [excludedDirectories].
  RegexScanner({
    List<String> extraTrustedHosts = const <String>[],
    this.excludedDirectories = const <String>[],
  }) : _trustedHosts = <String>{..._builtInTrustedHosts, ...extraTrustedHosts};

  /// Top level directories that are not scanned.
  final List<String> excludedDirectories;

  /// Reserved top level domains that never resolve on the internet
  /// (RFC 2606 and RFC 6761).
  static const _reservedTopLevelDomains = <String>{
    'invalid',
    'test',
    'example',
    'localhost',
    'local',
  };

  /// Hosts that the URL rule never reports, including their subdomains.
  static const _builtInTrustedHosts = <String>{
    'pub.dev',
    'dart.dev',
    'flutter.dev',
    'google.com',
    'googleapis.com',
    'github.com',
    'githubusercontent.com',
    'api.osv.dev',
    'w3.org',
    'example.com',
    'example.org',
    'localhost',
    '127.0.0.1',
    'apache.org',
    'opensource.org',
  };

  /// The trusted hosts in effect.
  final Set<String> _trustedHosts;

  /// The pattern extracting the host of a URL match.
  static final _hostPattern = RegExp(r'^https?://([^/:?#@\s]+)');

  /// Scans every regular file of [entries].
  ///
  /// Returns the findings ordered by severity, file and line.
  List<Finding> scan(List<ArchiveEntry> entries) {
    final findings = <Finding>[];
    final Iterable<ArchiveEntry> candidates = entries.where(
      (entry) =>
          entry.isText && !isInExcludedDirectory(entry, excludedDirectories),
    );
    for (final entry in candidates) {
      final String extension = _extension(entry.baseName);
      final Iterable<RegexRule> rules = RegexRules.all.where(
        (rule) => rule.extensions.contains(extension),
      );
      for (final rule in rules) {
        findings.addAll(_apply(rule, entry));
      }
    }
    return findings..sort((a, b) {
      final int bySeverity = a.severity.rank.compareTo(b.severity.rank);
      if (bySeverity != 0) {
        return bySeverity;
      }
      return '${a.location}'.compareTo('${b.location}');
    });
  }

  /// Applies [rule] to [entry].
  ///
  /// Returns the findings of that rule.
  List<Finding> _apply(RegexRule rule, ArchiveEntry entry) {
    if (rule.wholeFile) {
      return _applyToFile(rule, entry);
    }
    if (rule.checksHost && entry.path.endsWith('.dart')) {
      return _applyToLiterals(rule, entry);
    }
    final findings = <Finding>[];
    final List<String> lines = entry.text.split('\n');
    for (var index = 0; index < lines.length; index++) {
      final String line = lines[index];
      if (rule.checksHost && _isCommentLine(line)) {
        continue;
      }
      final Match? match = _firstRelevantMatch(rule, line);
      if (match != null) {
        findings.add(_finding(rule, entry, index + 1, line));
      }
    }
    return findings;
  }

  /// Applies the URL [rule] to the string literals of the Dart file
  /// [entry], so that links in comments and documentation are ignored.
  ///
  /// Returns at most one finding per line.
  List<Finding> _applyToLiterals(RegexRule rule, ArchiveEntry entry) {
    final findings = <int, Finding>{};
    final List<String> lines = entry.text.split('\n');
    for (final StringLiteral literal in DartLiteralTokenizer(
      entry.text,
    ).extract()) {
      final Match? match = _firstRelevantMatch(rule, literal.value);
      if (match == null || findings.containsKey(literal.line)) {
        continue;
      }
      if (_isProse(literal.value, match)) {
        continue;
      }
      final String line = literal.line <= lines.length
          ? lines[literal.line - 1]
          : '';
      findings[literal.line] = _finding(rule, entry, literal.line, line);
    }
    return findings.values.toList();
  }

  /// Whether the URL [match] is only mentioned inside a human readable
  /// message, such as a link in an error text, instead of being an
  /// endpoint. Endpoints are literals without whitespace or literals that
  /// start with the URL.
  ///
  /// Returns `true` for URLs embedded in prose.
  bool _isProse(String literal, Match match) {
    final bool hasWhitespace = RegExp(r'\s').hasMatch(literal.trim());
    final bool startsWithUrl = literal.trimLeft().startsWith(match[0] ?? '');
    return hasWhitespace && !startsWithUrl;
  }

  /// Applies a whole file [rule] to [entry].
  ///
  /// Returns one finding per match, located at the starting line.
  List<Finding> _applyToFile(RegexRule rule, ArchiveEntry entry) {
    final String text = entry.text;
    final findings = <Finding>[];
    for (final RegExpMatch match in rule.pattern.allMatches(text)) {
      final int line =
          '\n'.allMatches(text.substring(0, match.start)).length + 1;
      final String excerpt = text
          .substring(match.start, match.end)
          .split('\n')
          .first;
      findings.add(_finding(rule, entry, line, excerpt));
    }
    return findings;
  }

  /// Finds the first match of [rule] in [line] that is not excused by the
  /// trusted host list.
  ///
  /// Returns the match, or `null`.
  Match? _firstRelevantMatch(RegexRule rule, String line) {
    final Iterable<RegExpMatch> matches = rule.pattern.allMatches(line);
    if (!rule.checksHost) {
      return matches.firstOrNull;
    }
    return matches.where((m) => !_isTrusted(m[0] ?? '')).firstOrNull;
  }

  /// Whether the host of [url] is trusted, including its subdomains.
  ///
  /// Returns `true` for trusted hosts.
  bool _isTrusted(String url) {
    final String? host = _hostPattern.firstMatch(url)?[1]?.toLowerCase();
    if (host == null) {
      return false;
    }
    if (_reservedTopLevelDomains.contains(host.split('.').last)) {
      return true;
    }
    return _trustedHosts.any(
      (trusted) => host == trusted || host.endsWith('.$trusted'),
    );
  }

  /// Whether [line] is a comment in Dart or a script language.
  ///
  /// Returns `true` for comment lines.
  bool _isCommentLine(String line) {
    final String trimmed = line.trimLeft();
    return trimmed.startsWith('//') ||
        trimmed.startsWith('*') ||
        trimmed.startsWith('/*') ||
        trimmed.startsWith('#') ||
        trimmed.startsWith('REM ');
  }

  /// Creates the finding of [rule] at [line] of [entry].
  ///
  /// Returns the finding.
  Finding _finding(RegexRule rule, ArchiveEntry entry, int line, String text) =>
      Finding(
        ruleId: rule.id,
        source: FindingSource.regex,
        severity: rule.severity,
        title: rule.description,
        location: SourceLocation(entry.path, line: line),
        snippet: SnippetSanitizer.sanitize(text),
      );

  /// Returns the lower case extension of [fileName], including the dot.
  String _extension(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot).toLowerCase();
  }
}
