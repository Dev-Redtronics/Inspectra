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

import 'package:args/args.dart';
import 'package:inspectra/src/baseline/baseline.dart';
import 'package:inspectra/src/baseline/baseline_candidate.dart';
import 'package:inspectra/src/baseline/baseline_candidates.dart';
import 'package:inspectra/src/baseline/baseline_entry.dart';
import 'package:inspectra/src/baseline/baseline_report.dart';
import 'package:inspectra/src/baseline/baseline_run.dart';
import 'package:inspectra/src/baseline/baseline_scope.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/inspectra_command.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/quality/lint_result.dart';
import 'package:inspectra/src/quality/quality_command.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/scan/scan_result.dart' as supply_chain;
import 'package:inspectra/src/scan/scan_service.dart';
import 'package:inspectra/src/style/style_result.dart';
import 'package:inspectra/src/trivy/finding.dart';
import 'package:inspectra/src/trivy/trivy_command.dart';
import 'package:inspectra/src/trivy/trivy_exception.dart';
import 'package:inspectra/src/trivy/trivy_provision.dart';
import 'package:inspectra/src/util/dart_tool_exception.dart';

/// The common part of `baseline create` and `baseline prune`: runs the
/// selected scopes, updates the baseline and writes it.
///
/// A scope that cannot run completely - OSV.dev unreachable, Trivy or
/// `dart` unavailable - fails the command with `69` before anything is
/// written, so that an incomplete run never shrinks or replaces the
/// baseline.
abstract class BaselineUpdateCommand extends InspectraCommand {
  /// Creates the command with its `--only` and `--recursive` options.
  BaselineUpdateCommand(super.context) : super(withTrivyOptions: true) {
    argParser
      ..addMultiOption(
        'only',
        valueHelp: 'SCOPE',
        allowed: BaselineScope.values.map((scope) => scope.id),
        help:
            'Run only these scopes. Default: scan, and lint, style and trivy '
            'when they are enabled.',
      )
      ..addFlag(
        'recursive',
        abbr: 'r',
        negatable: false,
        help: 'Also scan nested packages (monorepos and pub workspaces).',
      );
  }

  /// The action in the report, `create` or `prune`.
  String get action;

  /// Updates [current] with the findings [candidates] for the entries that
  /// [covers] selects.
  ///
  /// Returns the new baseline.
  Baseline update(
    Baseline current,
    bool Function(BaselineEntry entry) covers,
    List<BaselineCandidate> candidates,
  );

  /// Runs the selected scopes and writes the updated baseline when it
  /// changed.
  ///
  /// Returns the report.
  ///
  /// Throws an [UnavailableException] when a scope cannot run completely or
  /// the file cannot be written, and an [InvalidInputException] when the
  /// baseline file or an input of a scope is malformed.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    final List<BaselineScope> scopes = _scopes(session.config, results);
    final String path = session.resolve(session.config.baseline.file);
    final before = Baseline.load(path);
    final candidates = <BaselineCandidate>[];
    final coverage = <bool Function(BaselineEntry entry)>[];
    for (final scope in scopes) {
      final BaselineRun run = await _run(
        scope,
        session,
        recursive: results['recursive'] == true,
      );
      candidates.addAll(run.candidates);
      coverage.add(run.covers);
    }
    bool covers(BaselineEntry entry) => coverage.any((test) => test(entry));
    final Baseline after = update(before, covers, candidates);
    final bool exists = File(path).existsSync();
    final bool changed = !exists || after.render() != before.render();
    if (changed) {
      after.write(path);
    }
    return BaselineReport(
      action: action,
      file: session.display(path),
      scopes: scopes,
      before: before,
      after: after,
      changed: changed,
    );
  }

  /// Selects the scopes from `--only`, or the default ones of [config].
  ///
  /// Returns the scopes in their declaration order.
  List<BaselineScope> _scopes(InspectraConfig config, ArgResults results) {
    final named = results['only'] as List<String>;
    if (named.isNotEmpty) {
      return BaselineScope.values
          .where((scope) => named.contains(scope.id))
          .toList();
    }
    return <BaselineScope>[
      BaselineScope.scan,
      if (config.lint.enabled) BaselineScope.lint,
      if (config.style.enabled) BaselineScope.style,
      if (config.trivy.enabled) BaselineScope.trivy,
    ];
  }

  /// Runs [scope] in the package of [session].
  ///
  /// Returns the current findings of the scope.
  Future<BaselineRun> _run(
    BaselineScope scope,
    CommandSession session, {
    required bool recursive,
  }) {
    session.console.info('Collecting the ${scope.id} findings...');
    return switch (scope) {
      BaselineScope.scan => _scan(session, recursive: recursive),
      BaselineScope.lint => _lint(session),
      BaselineScope.style => _style(session),
      BaselineScope.trivy => _trivy(session),
    };
  }

  /// Runs `scan` without the baseline, but with ignore rules and the
  /// severity filter.
  ///
  /// Returns the findings; Trivy and the dependency confusion check count
  /// only when they ran.
  Future<BaselineRun> _scan(
    CommandSession session, {
    required bool recursive,
  }) async {
    final service = ScanService(
      auditService: session.auditService(),
      typosquatDetector: session.typosquatDetector(),
      confusionDetector: session.confusionDetector(),
      trivyService: session.trivyService(),
      workingDirectory: session.workingDirectory,
    );
    final supply_chain.ScanResult result = await service.scan(
      session.workingDirectory,
      recursive: recursive,
      onStatus: session.console.info,
    );
    final bool trivyRan = result.trivy.ran;
    final bool confusionRan = result.confusionChecked;
    return BaselineRun(
      candidates: session
          .filter(baseline: false)
          .apply(result.findings)
          .kept
          .map(findingCandidate)
          .toList(),
      covers: (entry) =>
          entry.scope == BaselineScope.scan &&
          (trivyRan || entry.source != FindingSource.trivy.id) &&
          (confusionRan || entry.source != FindingSource.confusion.id),
    );
  }

  /// Runs `dart analyze`.
  ///
  /// Returns every diagnostic.
  ///
  /// Throws an [UnavailableException] when `dart analyze` fails.
  Future<BaselineRun> _lint(CommandSession session) async {
    final LintResult result;
    try {
      result = await runLintCheck(session.config, session.workingDirectory);
    } on DartToolException catch (error) {
      throw UnavailableException('$error');
    }
    return BaselineRun(
      candidates: result.issues.map(lintCandidate).toList(),
      covers: (entry) => entry.scope == BaselineScope.lint,
    );
  }

  /// Runs the style check.
  ///
  /// Returns every violation.
  Future<BaselineRun> _style(CommandSession session) async {
    final StyleResult result = await runStyleCheck(
      session.config,
      session.workingDirectory,
    );
    return BaselineRun(
      candidates: result.violations.map(styleCandidate).toList(),
      covers: (entry) => entry.scope == BaselineScope.style,
    );
  }

  /// Provisions Trivy and runs the configured scans.
  ///
  /// Returns the findings; a skipped scan leaves its entries unchanged.
  ///
  /// Throws an [UnavailableException] when Trivy is unavailable or fails.
  Future<BaselineRun> _trivy(CommandSession session) async {
    final TrivyProvision provision = await session.trivyProvisioner().provision(
      onStatus: session.console.info,
    );
    final List<ScanResult> results;
    switch (provision) {
      case TrivyUnavailable(:final reason):
        throw UnavailableException(reason);
      case TrivyAvailable(:final executable):
        try {
          results = await runTrivyScans(
            session.config,
            session.workingDirectory,
            executable: executable,
          );
        } on TrivyException catch (error) {
          throw UnavailableException(error.message);
        } on FileSystemException catch (error) {
          throw InvalidInputException('${error.message}: ${error.path ?? ''}');
        }
    }
    final Set<String> ran = results
        .where((result) => result.skipped == null)
        .map((result) => result.scan)
        .toSet();
    return BaselineRun(
      candidates: <BaselineCandidate>[
        for (final result in results)
          for (final finding in result.findings)
            scanCandidate(result.scan, finding),
      ],
      covers: (entry) =>
          entry.scope == BaselineScope.trivy && ran.contains(entry.source),
    );
  }
}
