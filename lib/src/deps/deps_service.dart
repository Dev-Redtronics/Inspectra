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

import 'package:inspectra/src/deps/dependency_fixer.dart';
import 'package:inspectra/src/deps/dependency_policy.dart';
import 'package:inspectra/src/deps/deps_result.dart';
import 'package:inspectra/src/deps/outdated_outcome.dart';
import 'package:inspectra/src/deps/outdated_policy.dart';
import 'package:inspectra/src/deps/policy_source.dart';
import 'package:inspectra/src/deps/pubspec_fix.dart';
import 'package:inspectra/src/inspect/pubspec_scanner.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/pub/project_discovery.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/pub/pubspec_parser.dart';
import 'package:inspectra/src/util/display_path.dart';
import 'package:inspectra/src/workspace/workspace.dart';
import 'package:inspectra/src/workspace/workspace_reference.dart';
import 'package:path/path.dart' as p;

/// Checks the pubspecs of a project: the built-in pubspec rules and, when
/// configured, the dependency policy, optionally after fixing what can be
/// fixed. Only [runOnline] with an outdated policy opens connections.
final class DepsService {
  /// Creates the service; [policy] and [fixer] are `null` while the
  /// dependency policy is disabled, and paths are shown relative to
  /// [workingDirectory].
  const DepsService({
    required this.workingDirectory,
    this.policy,
    this.fixer,
    this.scanner = const PubspecScanner(),
  });

  /// The directory display paths are relative to.
  final String workingDirectory;

  /// The dependency policy, or `null` when it is disabled.
  final DependencyPolicy? policy;

  /// Fixes the pubspecs, or `null` when the policy is disabled.
  final DependencyFixer? fixer;

  /// The built-in pubspec rules.
  final PubspecScanner scanner;

  /// Checks the `pubspec.yaml` in [root], and with [recursive] every one
  /// below it - for a pub workspace root, its members; with [fix], the
  /// fixable rules are applied to the files first. [trackedFiles], the
  /// absolute paths of the files Git tracks, lets the policy check whether
  /// lockfiles are committed, and [include] selects the pubspecs to check
  /// by their absolute path.
  ///
  /// Returns the findings and the applied fixes.
  ///
  /// Throws an [InvalidInputException] when there is no pubspec or a
  /// pubspec or lockfile is malformed, and an [UnavailableException] when a
  /// fixed pubspec cannot be written.
  DepsResult run(
    String root, {
    required bool recursive,
    bool fix = false,
    Set<String>? trackedFiles,
    bool Function(String pubspecPath)? include,
  }) => _run(
    root,
    recursive: recursive,
    fix: fix,
    trackedFiles: trackedFiles,
    include: include,
  ).$1;

  /// Checks the pubspecs like [run], and with [outdated] also how far their
  /// dependencies are behind the latest releases of the registry; without
  /// it, the result tells that these rules were not checked when they are
  /// configured.
  ///
  /// Returns the findings, the applied fixes and the libyears.
  ///
  /// Throws an [InvalidInputException] when there is no pubspec or a
  /// pubspec or lockfile is malformed, and an [UnavailableException] when a
  /// fixed pubspec cannot be written or a registry cannot be queried.
  Future<DepsResult> runOnline(
    String root, {
    required bool recursive,
    required OutdatedPolicy? outdated,
    bool fix = false,
    Set<String>? trackedFiles,
    bool Function(String pubspecPath)? include,
  }) async {
    final (DepsResult result, List<PolicySource> sources) = _run(
      root,
      recursive: recursive,
      fix: fix,
      trackedFiles: trackedFiles,
      include: include,
    );
    final bool configured = policy?.config.hasOutdatedRules ?? false;
    if (!configured) {
      return result;
    }
    if (outdated == null) {
      return DepsResult(
        pubspecs: result.pubspecs,
        findings: result.findings,
        fixes: result.fixes,
        outdatedChecked: false,
      );
    }
    final findings = <Finding>[...result.findings];
    double? libyears;
    for (final source in sources) {
      final OutdatedOutcome outcome = await outdated.check(source);
      findings.addAll(outcome.findings);
      final double? years = outcome.libyears;
      if (years != null) {
        libyears = (libyears ?? 0) + years;
      }
    }
    return DepsResult(
      pubspecs: result.pubspecs,
      findings: findings,
      fixes: result.fixes,
      outdatedChecked: true,
      libyears: libyears,
    );
  }

  /// Checks the pubspecs as [run] describes.
  ///
  /// Returns the result and the source of every package the policy
  /// checked.
  ///
  /// Throws an [InvalidInputException] when there is no pubspec or a
  /// pubspec or lockfile is malformed, and an [UnavailableException] when a
  /// fixed pubspec cannot be written.
  (DepsResult, List<PolicySource>) _run(
    String root, {
    required bool recursive,
    required bool fix,
    required Set<String>? trackedFiles,
    required bool Function(String pubspecPath)? include,
  }) {
    final List<String> paths = ProjectDiscovery(root)
        .find('pubspec.yaml', recursive: recursive, workspace: true)
        .where(include ?? (_) => true)
        .toList();
    if (paths.isEmpty) {
      throw InvalidInputException(
        'No pubspec.yaml found in ${displayPath(root, workingDirectory)}.',
      );
    }
    final findings = <Finding>[];
    final fixes = <String>[];
    final sources = <PolicySource>[];
    for (final path in paths) {
      final String display = displayPath(path, workingDirectory);
      final String original = File(path).readAsStringSync();
      final PubspecFix? fixed = fix ? _fix(path, original, display) : null;
      final String content = fixed?.content ?? original;
      fixes.addAll(<String>[
        for (final String change in fixed?.applied ?? const <String>[])
          '$display: $change',
      ]);
      final Pubspec pubspec = const PubspecParser().parse(
        content,
        path: display,
      );
      final DependencyPolicy? active = policy;
      final Set<String> siblings = Workspace.packagesAround(
        p.dirname(path),
        pubspec,
      );
      findings.addAll(
        scanner
            .scan(pubspec, content: content, displayPath: display)
            .where(
              (finding) =>
                  !(active?.justifies(finding) ?? false) &&
                  !isWorkspaceReference(finding, siblings),
            ),
      );
      if (active != null) {
        final source = PolicySource.forPubspec(
          pubspecPath: path,
          content: content,
          pubspec: pubspec,
          workingDirectory: workingDirectory,
          trackedFiles: trackedFiles,
        );
        sources.add(source);
        findings.addAll(active.check(source));
      }
    }
    final result = DepsResult(
      pubspecs: <String>[
        for (final path in paths) displayPath(path, workingDirectory),
      ],
      findings: findings,
      fixes: fixes,
    );
    return (result, sources);
  }

  /// Fixes the pubspec at [path] with the [content], shown as [display],
  /// and writes it when anything changed.
  ///
  /// Returns the fix, or `null` without a fixer.
  ///
  /// Throws an [UnavailableException] when the file cannot be written.
  PubspecFix? _fix(String path, String content, String display) {
    final DependencyFixer? active = fixer;
    if (active == null) {
      return null;
    }
    final PubspecFix result = active.fix(
      content,
      const PubspecParser().parse(content, path: display),
    );
    if (!result.changed) {
      return result;
    }
    final temporary = File('$path.tmp');
    try {
      temporary
        ..writeAsStringSync(result.content, flush: true)
        ..renameSync(path);
    } on FileSystemException catch (error) {
      throw UnavailableException('Cannot write $display: ${error.message}');
    }
    return result;
  }
}
