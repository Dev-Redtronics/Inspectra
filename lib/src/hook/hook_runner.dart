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

import 'package:inspectra/src/changelog/git_history.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/deps/dependency_policy.dart';
import 'package:inspectra/src/deps/policy_source.dart';
import 'package:inspectra/src/hook/hook_run_report.dart';
import 'package:inspectra/src/inspect/pubspec_scanner.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/model/source_location.dart';
import 'package:inspectra/src/policy/filter_outcome.dart';
import 'package:inspectra/src/pub/dependency_spec.dart';
import 'package:inspectra/src/pub/lockfile.dart';
import 'package:inspectra/src/pub/lockfile_parser.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/pub/pubspec_key_locator.dart';
import 'package:inspectra/src/pub/pubspec_parser.dart';
import 'package:inspectra/src/quality/format_check.dart';
import 'package:inspectra/src/style/style_check.dart';
import 'package:inspectra/src/style/style_result.dart';
import 'package:inspectra/src/typosquat/confusion_detector.dart';
import 'package:inspectra/src/util/files.dart';
import 'package:path/path.dart' as p;

/// Runs the checks of `hook.checks` on the files staged for the next
/// commit: the dependency checks and the style check on the content in
/// the index, the format check on the working tree.
final class HookRunner {
  /// Creates the runner of the services of [session].
  const HookRunner(this.session);

  /// The command session with the configuration and the services.
  final CommandSession session;

  /// Runs the configured checks on the staged files.
  ///
  /// Returns the report.
  ///
  /// Throws an `InvalidUsageException` outside of a Git repository, an
  /// `UnavailableException` when Git or a service fails, and an
  /// `InvalidInputException` for a malformed staged pubspec or lockfile.
  Future<HookRunReport> run() async {
    final InspectraConfig config = session.config;
    final List<HookCheck> checks = config.hook.checks;
    final git = GitHistory(
      processRunner: session.context.processRunner,
      workingDirectory: session.workingDirectory,
    );
    final List<String> staged = await git.stagedFiles();
    final findings = <Finding>[];
    final looked = <String>{};
    for (final path in staged) {
      final String name = p.posix.basename(path);
      final lockfile = name == 'pubspec.lock';
      final pubspec = name == 'pubspec.yaml';
      if (lockfile && checks.contains(HookCheck.audit)) {
        looked.add(path);
        findings.addAll(await _audit(path, await git.stagedContent(path)));
      }
      final bool pubspecChecks =
          checks.contains(HookCheck.typosquat) ||
          checks.contains(HookCheck.deps);
      if (pubspec && pubspecChecks) {
        looked.add(path);
        findings.addAll(
          await _pubspec(path, await git.stagedContent(path), checks),
        );
      }
    }
    final bool dartChecks =
        checks.contains(HookCheck.format) || checks.contains(HookCheck.style);
    final List<String> dart = dartChecks
        ? _dartFiles(staged, config)
        : const <String>[];
    looked.addAll(dart);
    final Set<String> unstaged = dart.isEmpty
        ? const <String>{}
        : (await git.stagedFiles(unstaged: true)).toSet();
    if (dart.isNotEmpty && checks.contains(HookCheck.format)) {
      findings.addAll(await _format(dart, config));
    }
    if (dart.isNotEmpty && checks.contains(HookCheck.style)) {
      findings.addAll(await _style(dart, config, git));
    }
    final FilterOutcome outcome = session.filter().apply(findings);
    return HookRunReport(
      checks: checks,
      staged: looked.toList()..sort(),
      findings: outcome.kept,
      partiallyStaged: checks.contains(HookCheck.format)
          ? <String>[
              for (final path in dart)
                if (unstaged.contains(path)) path,
            ]
          : const <String>[],
    );
  }

  /// Audits the staged lockfile at [path] with [content] against OSV.dev.
  ///
  /// Returns the findings.
  Future<List<Finding>> _audit(String path, String content) async {
    final Lockfile lockfile = const LockfileParser().parse(content, path: path);
    return (await session.auditService().audit(
      lockfile,
      displayPath: path,
    )).findings;
  }

  /// Checks the staged pubspec at [path] with [content]: typosquatting and
  /// dependency confusion, and the pubspec rules and dependency policy, as
  /// [checks] select.
  ///
  /// Returns the findings.
  Future<List<Finding>> _pubspec(
    String path,
    String content,
    List<HookCheck> checks,
  ) async {
    final Pubspec pubspec = const PubspecParser().parse(content, path: path);
    final List<String> lines = content.split('\n');
    SourceLocation locate(String name) => locatePubspecKey(lines, name, path);
    final findings = <Finding>[];
    if (checks.contains(HookCheck.typosquat)) {
      findings.addAll(
        session.typosquatDetector().analyze(
          pubspec.declaredNames,
          locate: locate,
        ),
      );
      final ConfusionDetector? confusion = session.confusionDetector();
      if (confusion != null) {
        findings.addAll(
          await confusion.analyze(<String, DependencySpec>{
            ...pubspec.dependencies,
            ...pubspec.devDependencies,
          }, locate: locate),
        );
      }
    }
    if (checks.contains(HookCheck.deps)) {
      final DependencyPolicy? policy = session.dependencyPolicy();
      findings
        ..addAll(
          const PubspecScanner()
              .scan(pubspec, content: content, displayPath: path)
              .where((finding) => !(policy?.justifies(finding) ?? false)),
        )
        ..addAll(
          policy?.check(
                PolicySource.forPubspec(
                  pubspecPath: session.resolve(path),
                  content: content,
                  pubspec: pubspec,
                  workingDirectory: session.workingDirectory,
                ),
              ) ??
              const <Finding>[],
        );
    }
    return findings;
  }

  /// Selects the staged Dart files the format or style check covers.
  ///
  /// Returns their paths.
  List<String> _dartFiles(List<String> staged, InspectraConfig config) {
    final covered = <String>{
      ...listFiles(
        session.workingDirectory,
        config.format.include,
        config.format.exclude,
      ),
      ...listFiles(
        session.workingDirectory,
        config.style.include,
        config.style.exclude,
      ),
    };
    return <String>[
      for (final path in staged)
        if (path.endsWith('.dart') && covered.contains(path)) path,
    ];
  }

  /// Checks the formatting of the [files] in the working tree.
  ///
  /// Returns one finding per unformatted file.
  Future<List<Finding>> _format(
    List<String> files,
    InspectraConfig config,
  ) async {
    final FormatResult result = await checkFormat(
      config: config.format,
      packageRoot: session.workingDirectory,
      files: files,
    );
    return <Finding>[
      for (final String path in result.unformatted)
        Finding(
          ruleId: 'UNFORMATTED',
          source: FindingSource.quality,
          severity: Severity.low,
          title: 'The file is not formatted',
          description: 'Run "dart format $path".',
          location: SourceLocation(path),
        ),
    ];
  }

  /// Checks the staged content of the [files] against the style rules,
  /// reading it through [git].
  ///
  /// Returns one finding per violation.
  Future<List<Finding>> _style(
    List<String> files,
    InspectraConfig config,
    GitHistory git,
  ) async {
    final StyleResult result = await checkStyle(
      config: config.style,
      packageRoot: session.workingDirectory,
      files: files,
      read: (path) async =>
          files.contains(path) ? git.stagedContent(path) : null,
    );
    return <Finding>[
      for (final violation in result.violations)
        Finding(
          ruleId: violation.ruleId,
          source: FindingSource.style,
          severity: Severity.low,
          title: violation.message,
          location: SourceLocation(violation.path, line: violation.line),
        ),
    ];
  }
}
