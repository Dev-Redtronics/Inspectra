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

import 'dart:io';

import 'package:inspectra/src/audit/audit_scan.dart';
import 'package:inspectra/src/audit/audit_service.dart';
import 'package:inspectra/src/deps/dependency_policy.dart';
import 'package:inspectra/src/deps/policy_source.dart';
import 'package:inspectra/src/inspect/pubspec_scanner.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/pub/dependency_spec.dart';
import 'package:inspectra/src/pub/lockfile.dart';
import 'package:inspectra/src/pub/lockfile_parser.dart';
import 'package:inspectra/src/pub/project_discovery.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/pub/pubspec_key_locator.dart';
import 'package:inspectra/src/pub/pubspec_parser.dart';
import 'package:inspectra/src/scan/scan_result.dart';
import 'package:inspectra/src/trivy/trivy_outcome.dart';
import 'package:inspectra/src/trivy/trivy_service.dart';
import 'package:inspectra/src/typosquat/confusion_detector.dart';
import 'package:inspectra/src/typosquat/typosquat_detector.dart';
import 'package:inspectra/src/util/display_path.dart';
import 'package:inspectra/src/workspace/workspace.dart';
import 'package:inspectra/src/workspace/workspace_member.dart';
import 'package:inspectra/src/workspace/workspace_reference.dart';
import 'package:path/path.dart' as p;

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
    this.dependencyPolicy,
  });

  /// Audits lockfiles against OSV.dev.
  final AuditService auditService;

  /// Detects typosquatting.
  final TyposquatDetector typosquatDetector;

  /// Detects dependency confusion, or `null` when offline.
  final ConfusionDetector? confusionDetector;

  /// Runs Trivy.
  final TrivyService trivyService;

  /// The dependency policy, or `null` while it is disabled.
  final DependencyPolicy? dependencyPolicy;

  /// The directory display paths are relative to.
  final String workingDirectory;

  /// Scans the project in [root], including nested packages when
  /// [recursive] is set, and then also the pubspecs of the members of a
  /// pub workspace that share its root lockfile; [onStatus] receives
  /// progress messages.
  ///
  /// Returns the raw outcome.
  ///
  /// Throws an [InvalidInputException] when no `pubspec.lock` exists.
  Future<ScanResult> scan(
    String root, {
    required bool recursive,
    required void Function(String message) onStatus,
  }) async {
    final String rootDisplay = displayPath(root, workingDirectory);
    final List<String> lockfiles = ProjectDiscovery(root)
        .find('pubspec.lock', recursive: recursive);
    if (lockfiles.isEmpty) {
      throw InvalidInputException(
        'No pubspec.lock found in $rootDisplay. Run "dart pub get" first.',
      );
    }
    final audits = <AuditScan>[];
    final projectFindings = <Finding>[];
    final pubspecs = <String>[];
    for (final lockfilePath in lockfiles) {
      final String display = displayPath(lockfilePath, workingDirectory);
      onStatus('Auditing $display against OSV.dev...');
      final Lockfile lockfile = const LockfileParser().parseFile(lockfilePath);
      audits.add(await auditService.audit(lockfile, displayPath: display));
      final String pubspecPath = p.join(
        p.dirname(lockfilePath),
        'pubspec.yaml',
      );
      if (File(pubspecPath).existsSync()) {
        pubspecs.add(displayPath(pubspecPath, workingDirectory));
        projectFindings.addAll(await _checkPubspec(pubspecPath, onStatus));
      }
    }
    final Workspace? workspace = recursive ? Workspace.load(root) : null;
    for (final WorkspaceMember member
        in workspace?.members ?? const <WorkspaceMember>[]) {
      final String display = displayPath(member.pubspecPath, workingDirectory);
      if (!pubspecs.contains(display)) {
        pubspecs.add(display);
        projectFindings.addAll(
          await _checkPubspec(member.pubspecPath, onStatus),
        );
      }
    }
    final TrivyOutcome trivy = await trivyService.scan(
      root,
      displayPrefix: rootDisplay,
      onStatus: onStatus,
    );
    final List<Finding> osvFindings = audits
        .expand((audit) => audit.findings)
        .toList();
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

  /// Runs the pubspec, typosquat and confusion checks and the dependency
  /// policy for [pubspecPath].
  ///
  /// Returns the findings.
  Future<List<Finding>> _checkPubspec(
    String pubspecPath,
    void Function(String message) onStatus,
  ) async {
    final String display = displayPath(pubspecPath, workingDirectory);
    onStatus('Checking $display for supply chain risks...');
    final String content = File(pubspecPath).readAsStringSync();
    final Pubspec pubspec = const PubspecParser().parse(content, path: display);
    final List<String> lines = content.split('\n');
    final Set<String> siblings = Workspace.packagesAround(
      p.dirname(pubspecPath),
      pubspec,
    );
    final findings = <Finding>[
      ...const PubspecScanner()
          .scan(pubspec, content: content, displayPath: display)
          .where(
            (finding) =>
                !(dependencyPolicy?.justifies(finding) ?? false) &&
                !isWorkspaceReference(finding, siblings),
          ),
      ...typosquatDetector.analyze(
        pubspec.declaredNames,
        locate: (name) => locatePubspecKey(lines, name, display),
      ),
      ...?dependencyPolicy?.check(
        PolicySource.forPubspec(
          pubspecPath: pubspecPath,
          content: content,
          pubspec: pubspec,
          workingDirectory: workingDirectory,
        ),
      ),
    ];
    final ConfusionDetector? confusion = confusionDetector;
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
      final Iterable<String> keys = finding.identifiers.map(
        (id) => '${finding.packageName}@${finding.packageVersion}#$id',
      );
      return !keys.any(known.contains);
    }).toList();
  }
}
