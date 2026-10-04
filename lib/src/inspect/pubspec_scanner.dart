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

import 'package:pub_semver/pub_semver.dart';

import '../model/finding.dart';
import '../model/finding_source.dart';
import '../model/severity.dart';
import '../model/source_location.dart';
import '../pub/dependency_kind.dart';
import '../pub/dependency_spec.dart';
import '../pub/pubspec.dart';
import '../pub/pubspec_key_locator.dart';

/// Checks the dependency declarations of a `pubspec.yaml` for risky
/// patterns.
///
/// Rules:
///
/// * `WILDCARD_VERSION` / `ANY_VERSION` (HIGH): unconstrained versions, which
///   accept any future, possibly malicious release;
/// * `SUSPICIOUS_GIT_HOST` / `GIT_IP_ADDRESS` (CRITICAL): Git dependencies
///   on paste sites or raw IP addresses;
/// * `GIT_BRANCH_REF` (HIGH): Git dependencies on a mutable branch or on the
///   default branch;
/// * `INSECURE_URL` (HIGH): plain `http://` Git or registry URLs;
/// * `PATH_DEPENDENCY` (MEDIUM): local path dependencies;
/// * `DEPENDENCY_OVERRIDE` (MEDIUM): overrides bypassing resolution;
/// * `OLD_SDK_CONSTRAINT` (LOW): SDK constraints admitting Dart 2.
final class PubspecScanner {
  /// Creates a scanner.
  const PubspecScanner();

  /// Paste and file sharing hosts that never host legitimate packages.
  static const List<String> _suspiciousHosts = <String>[
    'pastebin.com',
    'hastebin.com',
    'dpaste.org',
    'transfer.sh',
    'gist.githubusercontent.com',
  ];

  /// Branch names that are mutable by design.
  static const Set<String> _branchRefs = <String>{
    'main',
    'master',
    'dev',
    'develop',
    'HEAD',
  };

  /// Matches URLs whose host is an IPv4 or IPv6 literal.
  static final RegExp _ipHost = RegExp(
    r'^(?:[a-z+]+://)?(?:[^@/]+@)?(?:\d{1,3}(?:\.\d{1,3}){3}|\[[0-9a-fA-F:]+\])',
  );

  /// Scans [pubspec], whose raw text [content] is used to find line numbers,
  /// and reports it as [displayPath].
  ///
  /// Returns the findings.
  List<Finding> scan(
    Pubspec pubspec, {
    required String content,
    required String displayPath,
  }) {
    final lines = content.split('\n');
    final findings = <Finding>[];
    final sections = <Map<String, DependencySpec>>[
      pubspec.dependencies,
      pubspec.devDependencies,
    ];
    for (final section in sections) {
      for (final entry in section.entries) {
        final location = locatePubspecKey(lines, entry.key, displayPath);
        findings.addAll(_checkDependency(entry.key, entry.value, location));
      }
    }
    for (final entry in pubspec.dependencyOverrides.entries) {
      final location = locatePubspecKey(lines, entry.key, displayPath);
      findings
        ..add(
          _finding(
            entry.key,
            'DEPENDENCY_OVERRIDE',
            Severity.medium,
            'Dependency override for "${entry.key}" — overrides bypass '
                'normal version resolution',
            location,
          ),
        )
        ..addAll(_checkSource(entry.key, entry.value, location));
    }
    final sdk = _oldSdk(pubspec.sdkConstraint, lines, displayPath);
    if (sdk != null) {
      findings.add(sdk);
    }
    return findings;
  }

  /// Checks one regular dependency.
  ///
  /// Returns the findings.
  List<Finding> _checkDependency(
    String name,
    DependencySpec spec,
    SourceLocation location,
  ) {
    final findings = _checkSource(name, spec, location);
    if (spec.kind != DependencyKind.hosted) {
      return findings;
    }
    final constraint = spec.constraint?.trim();
    if (constraint == '*') {
      findings.add(
        _finding(
          name,
          'WILDCARD_VERSION',
          Severity.high,
          'Dependency "$name" uses wildcard version constraint "*" — '
              'resolves to any version including malicious updates',
          location,
        ),
      );
    }
    if (constraint == null || constraint == 'any') {
      findings.add(
        _finding(
          name,
          'ANY_VERSION',
          Severity.high,
          'Dependency "$name" has no version constraint — it accepts any '
              'version',
          location,
        ),
      );
    }
    return findings;
  }

  /// Checks the source of a dependency: Git, path and registry URLs.
  ///
  /// Returns the findings.
  List<Finding> _checkSource(
    String name,
    DependencySpec spec,
    SourceLocation location,
  ) {
    final findings = <Finding>[];
    if (spec.kind == DependencyKind.path) {
      findings.add(
        _finding(
          name,
          'PATH_DEPENDENCY',
          Severity.medium,
          'Dependency "$name" uses path reference: ${spec.path} — path '
              'dependencies cannot be resolved by other projects',
          location,
        ),
      );
    }
    final url = spec.gitUrl ?? spec.hostedUrl;
    if (url != null && url.startsWith('http://')) {
      findings.add(
        _finding(
          name,
          'INSECURE_URL',
          Severity.high,
          'Dependency "$name" is fetched over unencrypted HTTP: $url',
          location,
        ),
      );
    }
    if (spec.kind == DependencyKind.git) {
      findings.addAll(_checkGit(name, spec, location));
    }
    return findings;
  }

  /// Checks a Git dependency.
  ///
  /// Returns the findings.
  List<Finding> _checkGit(
    String name,
    DependencySpec spec,
    SourceLocation location,
  ) {
    final findings = <Finding>[];
    final url = spec.gitUrl ?? '';
    final host = _suspiciousHosts.where(url.contains).firstOrNull;
    if (host != null) {
      findings.add(
        _finding(
          name,
          'SUSPICIOUS_GIT_HOST',
          Severity.critical,
          'Git dependency "$name" is hosted on $host',
          location,
        ),
      );
    }
    if (_ipHost.hasMatch(url)) {
      findings.add(
        _finding(
          name,
          'GIT_IP_ADDRESS',
          Severity.critical,
          'Git dependency "$name" points to a raw IP address: $url',
          location,
        ),
      );
    }
    final ref = spec.gitRef;
    if (ref == null || _branchRefs.contains(ref)) {
      final which = ref == null ? 'the default branch' : 'branch "$ref"';
      findings.add(
        _finding(
          name,
          'GIT_BRANCH_REF',
          Severity.high,
          'Git dependency "$name" follows $which — branch references are '
              'mutable and can be force-pushed; pin a commit or tag',
          location,
        ),
      );
    }
    return findings;
  }

  /// Checks whether the SDK [constraint] still admits Dart 2.
  ///
  /// Returns the finding, or `null`.
  Finding? _oldSdk(String? constraint, List<String> lines, String path) {
    if (constraint == null) {
      return null;
    }
    final VersionConstraint parsed;
    try {
      parsed = VersionConstraint.parse(constraint);
    } on FormatException {
      return null;
    }
    final allowsDart2 = parsed.allowsAny(
      VersionRange(min: Version(2, 0, 0), max: Version(3, 0, 0)),
    );
    if (!allowsDart2) {
      return null;
    }
    return _finding(
      'sdk',
      'OLD_SDK_CONSTRAINT',
      Severity.low,
      'SDK constraint "$constraint" admits Dart 2, which no longer '
          'receives security fixes',
      locatePubspecKey(lines, 'sdk', path),
    );
  }

  /// Creates a finding for dependency [name].
  ///
  /// Returns the finding.
  Finding _finding(
    String name,
    String rule,
    Severity severity,
    String description,
    SourceLocation location,
  ) {
    return Finding(
      ruleId: rule,
      source: FindingSource.pubspec,
      severity: severity,
      title: description,
      location: location,
      packageName: name == 'sdk' ? null : name,
    );
  }
}
