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

import '../model/finding.dart';
import '../model/finding_source.dart';
import '../model/severity.dart';
import '../model/source_location.dart';
import '../report/snippet_sanitizer.dart';

/// Converts Trivy's JSON report into Inspectra findings.
///
/// Supported result sections: `Vulnerabilities`, `Secrets`,
/// `Misconfigurations` and `Licenses`. Unknown sections are ignored, so
/// newer Trivy versions keep working.
final class TrivyReportMapper {
  /// Creates a mapper that prefixes every target path with [pathPrefix].
  const TrivyReportMapper({this.pathPrefix = ''});

  /// The prefix added to Trivy's target paths, for example the project
  /// directory relative to the working directory.
  final String pathPrefix;

  /// Maps the decoded Trivy [report].
  ///
  /// Returns the findings.
  List<Finding> map(Map<String, Object?> report) {
    final results = _maps(report['Results']);
    return <Finding>[for (final result in results) ..._mapResult(result)];
  }

  /// Maps one entry of `Results`.
  ///
  /// Returns its findings.
  List<Finding> _mapResult(Map<String, Object?> result) {
    final target = _path('${result['Target'] ?? ''}');
    return <Finding>[
      for (final vuln in _maps(result['Vulnerabilities']))
        _vulnerability(vuln, target),
      for (final secret in _maps(result['Secrets'])) _secret(secret, target),
      for (final misconfig in _maps(result['Misconfigurations']))
        if (misconfig['Status'] != 'PASS') _misconfiguration(misconfig, target),
      for (final license in _maps(result['Licenses']))
        _license(license, target),
    ];
  }

  /// Maps a detected vulnerability.
  ///
  /// Returns the finding.
  Finding _vulnerability(Map<String, Object?> json, String target) {
    final id = _string(json['VulnerabilityID']) ?? 'UNKNOWN';
    return Finding(
      ruleId: id,
      source: FindingSource.trivy,
      severity: Severity.parse(_string(json['Severity'])),
      title: _string(json['Title']) ?? id,
      description: _string(json['Description']) ?? '',
      location: SourceLocation(target),
      packageName: _string(json['PkgName']),
      packageVersion: _string(json['InstalledVersion']),
      fixedVersion: _string(json['FixedVersion']),
      aliases: _strings(json['VendorIDs']),
      url: _string(json['PrimaryURL']),
      attributes: const <String, Object?>{'kind': 'vulnerability'},
    );
  }

  /// Maps a detected secret; Trivy already redacts the secret value.
  ///
  /// Returns the finding.
  Finding _secret(Map<String, Object?> json, String target) {
    final match = _string(json['Match']);
    return Finding(
      ruleId: _string(json['RuleID']) ?? 'secret',
      source: FindingSource.trivy,
      severity: Severity.parse(_string(json['Severity'])),
      title: _string(json['Title']) ?? 'Hard-coded secret',
      location: SourceLocation(target, line: _int(json['StartLine'])),
      snippet: match == null ? null : SnippetSanitizer.sanitize(match),
      attributes: <String, Object?>{
        'kind': 'secret',
        'category': _string(json['Category']),
      },
    );
  }

  /// Maps a failed misconfiguration check.
  ///
  /// Returns the finding.
  Finding _misconfiguration(Map<String, Object?> json, String target) {
    final cause = json['CauseMetadata'];
    final line = cause is Map<String, Object?>
        ? _int(cause['StartLine'])
        : null;
    return Finding(
      ruleId: _string(json['ID']) ?? _string(json['AVDID']) ?? 'misconfig',
      source: FindingSource.trivy,
      severity: Severity.parse(_string(json['Severity'])),
      title: _string(json['Title']) ?? 'Misconfiguration',
      description:
          _string(json['Message']) ?? _string(json['Description']) ?? '',
      location: SourceLocation(target, line: line),
      url: _string(json['PrimaryURL']),
      attributes: <String, Object?>{
        'kind': 'misconfiguration',
        'resolution': _string(json['Resolution']),
      },
    );
  }

  /// Maps a detected license.
  ///
  /// Returns the finding.
  Finding _license(Map<String, Object?> json, String target) {
    final name = _string(json['Name']) ?? 'unknown';
    final category = _string(json['Category']) ?? 'unknown';
    final file = _string(json['FilePath']);
    return Finding(
      ruleId: 'LICENSE:$name',
      source: FindingSource.trivy,
      severity: Severity.parse(_string(json['Severity'])),
      title: 'License $name ($category)',
      location: SourceLocation(file == null ? target : _path(file)),
      packageName: _string(json['PkgName']),
      url: _string(json['Link']),
      attributes: <String, Object?>{'kind': 'license', 'category': category},
    );
  }

  /// Prefixes [path] with [pathPrefix].
  ///
  /// Returns the display path.
  String _path(String path) {
    if (pathPrefix.isEmpty || pathPrefix == '.') {
      return path;
    }
    return '$pathPrefix/$path';
  }

  /// Returns the maps contained in the list [value].
  List<Map<String, Object?>> _maps(Object? value) => value is List<Object?>
      ? value.whereType<Map<String, Object?>>().toList()
      : const <Map<String, Object?>>[];

  /// Returns the strings contained in the list [value].
  List<String> _strings(Object? value) => value is List<Object?>
      ? value.whereType<String>().toList()
      : const <String>[];

  /// Returns [value] when it is a non-empty string, otherwise `null`.
  String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  /// Returns [value] when it is a positive number, otherwise `null`.
  int? _int(Object? value) => value is num && value > 0 ? value.toInt() : null;
}
