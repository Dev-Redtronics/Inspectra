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
import 'package:inspectra/src/deps/policy_source.dart';
import 'package:inspectra/src/deps/pubspec_fix.dart';
import 'package:inspectra/src/inspect/pubspec_scanner.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/pub/project_discovery.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/pub/pubspec_parser.dart';
import 'package:inspectra/src/util/display_path.dart';

/// Checks the pubspecs of a project without any network access: the
/// built-in pubspec rules and, when configured, the dependency policy,
/// optionally after fixing what can be fixed.
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
  /// below it, such as the members of a pub workspace; with [fix], the
  /// fixable rules are applied to the files first.
  ///
  /// Returns the findings and the applied fixes.
  ///
  /// Throws an [InvalidInputException] when there is no pubspec or a
  /// pubspec or lockfile is malformed, and an [UnavailableException] when a
  /// fixed pubspec cannot be written.
  DepsResult run(String root, {required bool recursive, bool fix = false}) {
    final List<String> paths = ProjectDiscovery(root)
        .find('pubspec.yaml', recursive: recursive);
    if (paths.isEmpty) {
      throw InvalidInputException(
        'No pubspec.yaml found in ${displayPath(root, workingDirectory)}.',
      );
    }
    final findings = <Finding>[];
    final fixes = <String>[];
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
      findings.addAll(
        scanner.scan(pubspec, content: content, displayPath: display),
      );
      final DependencyPolicy? active = policy;
      if (active != null) {
        findings.addAll(
          active.check(
            PolicySource.forPubspec(
              pubspecPath: path,
              content: content,
              pubspec: pubspec,
              workingDirectory: workingDirectory,
            ),
          ),
        );
      }
    }
    return DepsResult(
      pubspecs: <String>[
        for (final path in paths) displayPath(path, workingDirectory),
      ],
      findings: findings,
      fixes: fixes,
    );
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
