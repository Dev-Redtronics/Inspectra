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

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/model/source_location.dart';

/// A single security relevant observation reported by any scanner.
///
/// Findings are immutable value objects. All scanners, from the OSV.dev audit
/// to the Trivy integration, produce this one type so that filtering, ignore
/// rules, exit code decisions and the JSON, SARIF and Markdown renderers work
/// uniformly.
final class Finding {
  /// Creates a finding.
  ///
  /// [ruleId] is the stable identifier of the rule or advisory, for example
  /// `PROCESS_RUN` or `GHSA-xxxx-yyyy-zzzz`. [source] names the scanner,
  /// [severity] the normalised severity and [title] a one line summary.
  /// All other parameters are optional details that renderers show when they
  /// are present.
  const Finding({
    required this.ruleId,
    required this.source,
    required this.severity,
    required this.title,
    this.description = '',
    this.location,
    this.packageName,
    this.packageVersion,
    this.fixedVersion,
    this.aliases = const <String>[],
    this.url,
    this.snippet,
    this.attributes = const <String, Object?>{},
  });

  /// Reads a finding from its JSON [json], as [toJson] writes it, found at
  /// [location] of an input file.
  ///
  /// Returns the finding.
  ///
  /// Throws an [InvalidInputException] when a required field is missing or
  /// the source or severity is unknown.
  factory Finding.fromJson(Object? json, String location) {
    if (json is! Map<String, Object?>) {
      throw InvalidInputException('$location must be an object.');
    }
    final Object? ruleId = json['ruleId'];
    final Object? title = json['title'];
    final FindingSource? source = FindingSource.tryParse('${json['source']}');
    final Iterable<Severity> severities = Severity.values.where(
      (severity) => severity.name == json['severity'],
    );
    final bool valid =
        ruleId is String &&
        title is String &&
        source != null &&
        severities.isNotEmpty;
    if (!valid) {
      throw InvalidInputException(
        '$location needs a ruleId, a title, a known source and a known '
        'severity.',
      );
    }
    final Object? file = json['file'];
    final Object? line = json['line'];
    final Object? aliases = json['aliases'];
    final Object? attributes = json['attributes'];
    return Finding(
      ruleId: ruleId,
      source: source,
      severity: severities.first,
      title: title,
      description: _text(json['description']) ?? '',
      location: file is String
          ? SourceLocation(file, line: line is int ? line : null)
          : null,
      packageName: _text(json['package']),
      packageVersion: _text(json['version']),
      fixedVersion: _text(json['fixedVersion']),
      aliases: <String>[
        if (aliases is List<Object?>)
          for (final Object? alias in aliases)
            if (alias is String) alias,
      ],
      url: _text(json['url']),
      snippet: _text(json['snippet']),
      attributes: attributes is Map<String, Object?>
          ? attributes
          : const <String, Object?>{},
    );
  }

  /// The stable identifier of the rule or advisory.
  final String ruleId;

  /// The scanner that produced this finding.
  final FindingSource source;

  /// The normalised severity.
  final Severity severity;

  /// A one line summary of the problem.
  final String title;

  /// A longer explanation, possibly empty.
  final String description;

  /// The file and line the finding refers to, if any.
  final SourceLocation? location;

  /// The affected package, if the finding concerns a dependency.
  final String? packageName;

  /// The affected package version, if known.
  final String? packageVersion;

  /// The first version that fixes the problem, if one exists.
  final String? fixedVersion;

  /// Alternative identifiers of the same advisory, such as CVE and GHSA ids.
  final List<String> aliases;

  /// A link to further information, if available.
  final String? url;

  /// The offending source excerpt, already sanitised for terminal output.
  final String? snippet;

  /// Scanner specific measurements, such as the `entropy` of a string or
  /// the `codepoint` of an invisible character. They appear in JSON and
  /// SARIF output.
  final Map<String, Object?> attributes;

  /// Every identifier this finding can be referred to by.
  ///
  /// Ignore rules match against this set, which is why `--ignore CVE-...`
  /// suppresses an advisory that OSV.dev reports under its GHSA id.
  Set<String> get identifiers => <String>{ruleId, ...aliases};

  /// A stable SHA-256 fingerprint of this finding.
  ///
  /// The fingerprint covers the source, rule, package coordinates and
  /// location but not the free text, so it survives rewording of advisory
  /// summaries. It is emitted as SARIF `partialFingerprints` so that code
  /// scanning platforms can track a finding across runs.
  String get fingerprint {
    final parts = <String>[
      source.id,
      ruleId,
      packageName ?? '',
      packageVersion ?? '',
      location?.path ?? '',
      '${location?.line ?? ''}',
    ];
    final Digest digest = sha256.convert(utf8.encode(parts.join('|')));
    return digest.toString();
  }

  /// Serialises this finding into a JSON compatible map.
  ///
  /// Absent optional values are omitted rather than written as `null` to keep
  /// documents compact.
  ///
  /// Returns the JSON representation.
  Map<String, Object?> toJson() {
    final SourceLocation? currentLocation = location;
    return <String, Object?>{
      'ruleId': ruleId,
      'source': source.id,
      'severity': severity.name,
      'title': title,
      if (description.isNotEmpty) 'description': description,
      if (currentLocation != null) 'file': currentLocation.path,
      if (currentLocation?.line != null) 'line': currentLocation?.line,
      if (packageName != null) 'package': packageName,
      if (packageVersion != null) 'version': packageVersion,
      if (fixedVersion != null) 'fixedVersion': fixedVersion,
      if (aliases.isNotEmpty) 'aliases': aliases,
      if (url != null) 'url': url,
      if (snippet != null) 'snippet': snippet,
      if (attributes.isNotEmpty) 'attributes': attributes,
      'fingerprint': fingerprint,
    };
  }

  /// Copies this finding with the [extra] attributes added to its own.
  ///
  /// Returns the copy.
  Finding withAttributes(Map<String, Object?> extra) => Finding(
    ruleId: ruleId,
    source: source,
    severity: severity,
    title: title,
    description: description,
    location: location,
    packageName: packageName,
    packageVersion: packageVersion,
    fixedVersion: fixedVersion,
    aliases: aliases,
    url: url,
    snippet: snippet,
    attributes: <String, Object?>{...attributes, ...extra},
  );

  /// Returns [value] when it is a text, otherwise `null`.
  static String? _text(Object? value) => value is String ? value : null;
}
