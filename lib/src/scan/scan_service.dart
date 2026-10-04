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

import 'dart:io';

import 'package:path/path.dart' as p;

import '../audit/audit_scan.dart';
import '../audit/audit_service.dart';
import '../inspect/pubspec_scanner.dart';
import '../model/finding.dart';
import '../model/finding_source.dart';
import '../model/inspectra_exception.dart';
import '../pub/dependency_spec.dart';
import '../pub/lockfile_parser.dart';
import '../pub/project_discovery.dart';
import '../pub/pubspec_key_locator.dart';
import '../pub/pubspec_parser.dart';
import '../trivy/trivy_outcome.dart';
import '../trivy/trivy_service.dart';
import '../typosquat/confusion_detector.dart';
import '../typosquat/typosquat_detector.dart';
import '../util/display_path.dart';
import 'scan_result.dart';

/// Runs every project level check in one pass: the OSV.dev audit, the
/// pubspec rules, typosquatting and dependency confusion detection, and
/// Trivy's vulnerability, secret, misconfiguration and license scanners.
///
/// Vulnerabilities reported by both OSV.dev and Trivy for the same package
/// version are reported once, keeping the OSV.dev record.
final class ScanService {
  /// Creates a scan service.
  ///
  /// [confusionDetector] is `null` in offline mode. [workingDirectory]
  /// anchors display paths.
  const ScanService({
    required this.auditService,
    required this.typosquatDetector,
    required this.confusionDetector,
    required this.trivyService,
    required this.workingDirectory,
  });

  /// Audits lockfiles against OSV.dev.
  final AuditService auditService;

  /// Detects typosquatting.
  final TyposquatDetector typosquatDetector;

  /// Detects dependency confusion, or `null` when offline.
  final ConfusionDetector? confusionDetector;

  /// Runs Trivy.
  final TrivyService trivyService;

  /// The directory display paths are relative to.
  final String workingDirectory;

  /// Scans the project in [root], including nested packages when
  /// [recursive] is set; [onStatus] receives progress messages.
  ///
  /// Returns the raw outcome.
  ///
  /// Throws an [InvalidInputException] when no `pubspec.lock` exists.
  Future<ScanResult> scan(
    String root, {
    required bool recursive,
    required void Function(String message) onStatus,
  }) async {
    final rootDisplay = displayPath(root, workingDirectory);
    final lockfiles = ProjectDiscovery(
      root,
    ).find('pubspec.lock', recursive: recursive);
    if (lockfiles.isEmpty) {
      throw InvalidInputException(
        'No pubspec.lock found in $rootDisplay. Run "dart pub get" first.',
      );
    }
    final audits = <AuditScan>[];
    final projectFindings = <Finding>[];
    final pubspecs = <String>[];
    for (final lockfilePath in lockfiles) {
      final display = displayPath(lockfilePath, workingDirectory);
      onStatus('Auditing $display against OSV.dev...');
      final lockfile = const LockfileParser().parseFile(lockfilePath);
      audits.add(await auditService.audit(lockfile, displayPath: display));
      final pubspecPath = p.join(p.dirname(lockfilePath), 'pubspec.yaml');
      if (File(pubspecPath).existsSync()) {
        pubspecs.add(displayPath(pubspecPath, workingDirectory));
        projectFindings.addAll(await _checkPubspec(pubspecPath, onStatus));
      }
    }
    final trivy = await trivyService.scan(
      root,
      displayPrefix: rootDisplay,
      onStatus: onStatus,
    );
    final osvFindings = audits.expand((audit) => audit.findings).toList();
    return ScanResult(
      root: rootDisplay,
      audits: audits,
      pubspecs: pubspecs,
      findings: <Finding>[
        ...osvFindings,
        ...projectFindings,
        ..._withoutDuplicates(trivy, osvFindings),
      ],
      trivy: trivy,
      confusionChecked: confusionDetector != null,
    );
  }

  /// Runs the pubspec, typosquat and confusion checks for [pubspecPath].
  ///
  /// Returns the findings.
  Future<List<Finding>> _checkPubspec(
    String pubspecPath,
    void Function(String message) onStatus,
  ) async {
    final display = displayPath(pubspecPath, workingDirectory);
    onStatus('Checking $display for supply chain risks...');
    final content = File(pubspecPath).readAsStringSync();
    final pubspec = const PubspecParser().parse(content, path: display);
    final lines = content.split('\n');
    final findings = <Finding>[
      ...const PubspecScanner().scan(
        pubspec,
        content: content,
        displayPath: display,
      ),
      ...typosquatDetector.analyze(
        pubspec.declaredNames,
        locate: (name) => locatePubspecKey(lines, name, display),
      ),
    ];
    final confusion = confusionDetector;
    if (confusion != null) {
      findings.addAll(
        await confusion.analyze(<String, DependencySpec>{
          ...pubspec.dependencies,
          ...pubspec.devDependencies,
        }, locate: (name) => locatePubspecKey(lines, name, display)),
      );
    }
    return findings;
  }

  /// Removes Trivy vulnerabilities already reported by OSV.dev for the same
  /// package version and advisory (compared by id and aliases).
  ///
  /// Returns the remaining Trivy findings.
  List<Finding> _withoutDuplicates(
    TrivyOutcome trivy,
    List<Finding> osvFindings,
  ) {
    final known = <String>{
      for (final finding in osvFindings)
        for (final id in finding.identifiers)
          '${finding.packageName}@${finding.packageVersion}#$id',
    };
    return trivy.findings.where((finding) {
      if (finding.source != FindingSource.trivy) {
        return true;
      }
      final keys = finding.identifiers.map(
        (id) => '${finding.packageName}@${finding.packageVersion}#$id',
      );
      return !keys.any(known.contains);
    }).toList();
  }
}
