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

import 'package:args/command_runner.dart';
import 'package:inspectra/src/api/api_command.dart';
import 'package:inspectra/src/api/semver_check.dart';
import 'package:inspectra/src/api/semver_result.dart';
import 'package:inspectra/src/baseline/baseline_gates.dart';
import 'package:inspectra/src/baseline/baseline_matcher.dart';
import 'package:inspectra/src/changelog/changelog_check.dart';
import 'package:inspectra/src/changelog/changelog_check_result.dart';
import 'package:inspectra/src/changelog/git_history.dart';
import 'package:inspectra/src/cli/command_context.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/config_bases.dart';
import 'package:inspectra/src/cli/exit_code.dart';
import 'package:inspectra/src/config/config_loader.dart';
import 'package:inspectra/src/config/config_overrides.dart';
import 'package:inspectra/src/config/config_profiles.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/coverage/coverage_gate.dart';
import 'package:inspectra/src/deps/dependency_policy.dart';
import 'package:inspectra/src/deps/deps_report.dart';
import 'package:inspectra/src/deps/deps_result.dart';
import 'package:inspectra/src/deps/deps_service.dart';
import 'package:inspectra/src/deps/outdated_policy.dart';
import 'package:inspectra/src/deps/tracked_files.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/io/console.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/net/http_transport.dart';
import 'package:inspectra/src/policy/filter_outcome.dart';
import 'package:inspectra/src/policy/finding_filter.dart';
import 'package:inspectra/src/pub/pub_package_cache.dart';
import 'package:inspectra/src/pub/registry_listings.dart';
import 'package:inspectra/src/quality/format_check.dart';
import 'package:inspectra/src/quality/lint.dart';
import 'package:inspectra/src/quality/quality_command.dart';
import 'package:inspectra/src/style/style_result.dart';
import 'package:inspectra/src/trivy/finding.dart';
import 'package:inspectra/src/trivy/trivy.dart';
import 'package:inspectra/src/trivy/trivy_command.dart';
import 'package:inspectra/src/trivy/trivy_provision.dart';
import 'package:inspectra/src/util/dart_tool.dart';
import 'package:inspectra/src/workspace/workspace.dart';
import 'package:inspectra/src/workspace/workspace_member.dart';
import 'package:inspectra/src/workspace/workspace_policy.dart';
import 'package:path/path.dart' as p;

/// The base of the package quality commands: `check`, `format`, `lint`,
/// `api`, `coverage` and the configured Trivy scans.
///
/// These commands work on a Dart package, read its configuration (which
/// requires a `pubspec.yaml`), print the rendered result of each check and
/// exit with `0` when every check passed and `1` otherwise. Failures of the
/// configuration or of an external tool map to the shared exit codes:
/// `65` for invalid configuration and `69` for unavailable tools.
abstract class PackageCheckCommand extends Command<int> {
  /// Creates a command running in [context], with the `--profile` option
  /// every check shares.
  PackageCheckCommand(this.context) {
    argParser.addOption(
      'profile',
      help:
          'Apply the configuration profile of this name, e.g. ci '
          '(default: INSPECTRA_PROFILE).',
      valueHelp: 'name',
    );
  }

  /// The outside world.
  final CommandContext context;

  /// The output channel for check results.
  StringSink get out => context.out;

  /// The package directory: the global `--directory` option resolved
  /// against the working directory of the [context].
  String get packageRoot {
    final global = globalResults?['directory'] as String?;
    return p.normalize(p.join(context.workingDirectory, global ?? '.'));
  }

  /// Runs the checks of the concrete command.
  ///
  /// Returns whether every check passed.
  Future<bool> runChecks();

  /// Prints the usage to standard output of the [context].
  @override
  void printUsage() => context.out.writeln(usage);

  /// Runs [runChecks] and maps its outcome and failures to an exit code.
  ///
  /// Returns the process exit code.
  @override
  Future<int> run() async {
    try {
      await prepareConfigBases(context, packageRoot);
      final bool passed = await runChecks();
      return passed ? ExitCode.success.code : ExitCode.findings.code;
    } on InspectraConfigException catch (error) {
      context.err.writeln('error: $error');
      return ExitCode.dataError.code;
    } on FileSystemException catch (error) {
      context.err.writeln('error: ${error.message}: ${error.path ?? ''}');
      return ExitCode.dataError.code;
    } on TrivyException catch (error) {
      context.err.writeln('error: $error');
      return ExitCode.unavailable.code;
    } on CoverageException catch (error) {
      context.err.writeln('error: $error');
      return ExitCode.unavailable.code;
    } on DartToolException catch (error) {
      context.err.writeln('error: $error');
      return ExitCode.unavailable.code;
    } on InspectraException catch (error) {
      context.err.writeln('error: ${error.message}');
      return ExitCode.of(error).code;
    }
  }

  /// Reads the configuration of the package, with the profile of
  /// `--profile`, `INSPECTRA_*` environment variables and the command line
  /// values [cli] layered on top, and warns about old option names.
  ///
  /// Returns the configuration.
  ///
  /// Throws a [FileSystemException] without `pubspec.yaml` and an
  /// [InspectraConfigException] for invalid configuration.
  InspectraConfig loadPackageConfig({
    Map<String, String> cli = const <String, String>{},
  }) {
    final profile = argResults?['profile'] as String?;
    final InspectraConfig config = loadConfig(
      packageRoot,
      overrides: ConfigOverrides(
        cli: <String, String>{...cli, profileOption: ?profile},
        environment: context.environment,
      ),
      cacheRoot: cacheRootOf(context),
    );
    for (final DeprecatedOption option in config.deprecatedOptions) {
      context.err.writeln('warning: ${option.describe()}');
    }
    return config;
  }

  /// Loads the baseline of the package as [config] names it.
  ///
  /// Returns the matcher, which covers nothing when the baseline is
  /// disabled or its file does not exist.
  ///
  /// Throws an `InvalidInputException` when the baseline file is malformed.
  BaselineMatcher baselineMatcher(InspectraConfig config) =>
      BaselineMatcher.load(
        config.baseline,
        packageRoot,
        unignorable: config.forbiddenIgnoreSeverities,
      );

  /// Runs the style check and prints the outcome.
  ///
  /// Returns whether it passed.
  ///
  /// Throws an `InvalidInputException` for a missing header template or
  /// custom rules that cannot run.
  Future<bool> runStyleGate(InspectraConfig config) async {
    final StyleResult result = baselineStyle(
      await runStyleCheck(config, packageRoot),
      baselineMatcher(config),
    );
    out.writeln(result.render());
    return !result.failed;
  }

  /// Checks the pubspec of the package against the pubspec rules and the
  /// dependency policy, with the ignore rules and the baseline applied, and
  /// prints the outcome.
  ///
  /// Returns whether no finding reached `fail_on`.
  ///
  /// Throws an `InvalidInputException` for a malformed pubspec or lockfile
  /// and an `UnavailableException` when the registry cannot be queried.
  Future<bool> runDependencyPolicy(InspectraConfig config) async {
    final DependencyPolicyConfig policy = config.dependencyPolicy;
    final bool online = policy.hasOutdatedRules && !config.network.offline;
    final HttpTransport? transport = online
        ? HttpTransport(
            config: config.network.withResolvedPaths(
              (path) => p.normalize(p.join(packageRoot, path)),
            ),
            environment: context.environment,
            sleep: context.sleep,
          )
        : null;
    try {
      final DepsResult result =
          await DepsService(
            workingDirectory: packageRoot,
            policy: DependencyPolicy(
              config: policy,
              defaultRegistry: config.network.pubHostedUrl,
              now: context.clock.now(),
            ),
          ).runOnline(
            packageRoot,
            recursive: false,
            trackedFiles: policy.lockfilePolicy == LockfilePolicy.any
                ? null
                : await trackedFiles(context.processRunner, packageRoot),
            outdated: transport == null
                ? null
                : OutdatedPolicy(
                    config: policy,
                    lookup: RegistryListings(
                      transport: transport,
                      cache: PubPackageCache(
                        p.join(cacheRootOf(context), 'pub'),
                      ),
                      clock: context.clock,
                    ).lookup,
                    defaultRegistry: config.network.pubHostedUrl,
                    concurrency: config.network.concurrency,
                  ),
          );
      return _reportDependencies(config, result, 'Dependency policy');
    } finally {
      transport?.close();
    }
  }

  /// Checks the pub workspace whose root is the package against the
  /// workspace policy, with the ignore rules and the baseline applied, and
  /// prints the outcome; a package that is no workspace root passes.
  ///
  /// Returns whether no finding reached `fail_on`.
  ///
  /// Throws an `InvalidInputException` for a malformed pubspec.
  bool runWorkspacePolicy(InspectraConfig config) {
    final Workspace? workspace = Workspace.load(packageRoot);
    if (workspace == null) {
      out.writeln(
        'Workspace policy: skipped, the package is no pub workspace root.',
      );
      return true;
    }
    final result = DepsResult(
      pubspecs: <String>[
        for (final WorkspaceMember member in workspace.members)
          p.posix.join(member.path, 'pubspec.yaml'),
      ],
      findings: WorkspacePolicy(config.workspacePolicy).check(workspace),
    );
    return _reportDependencies(config, result, 'Workspace policy');
  }

  /// Applies the ignore rules and the baseline of [config] to [result] and
  /// prints the outcome after the [label] of the step.
  ///
  /// Returns whether no finding reached `fail_on`.
  bool _reportDependencies(
    InspectraConfig config,
    DepsResult result,
    String label,
  ) {
    final FilterOutcome outcome = FindingFilter(
      minSeverity: config.minSeverity,
      rules: config.ignore,
      cliIgnores: const <String>[],
      now: context.clock.now(),
      baseline: baselineMatcher(config),
      unignorable: config.forbiddenIgnoreSeverities,
    ).apply(result.findings);
    final report = DepsReport(
      result: result,
      findings: outcome.kept,
      suppressedCount: outcome.suppressed.length,
      baselinedCount: outcome.baselined.length,
    );
    final text = StringBuffer();
    report.writeText(text, const AnsiStyler(enabled: false));
    out.write('$label: $text');
    return !report.isFailing(config.failOn ?? Severity.unknown);
  }

  /// Validates the changelog and prints the outcome.
  ///
  /// Returns whether the changelog is valid.
  ///
  /// Throws an `InvalidInputException` when `pubspec.yaml` is malformed.
  Future<bool> runChangelogCheck(InspectraConfig config) async {
    final ChangelogCheckResult result = checkChangelog(config, packageRoot);
    out.writeln(result.render());
    return !result.failed;
  }

  /// Compares the API with the last release and checks the version in
  /// `pubspec.yaml`, printing the outcome.
  ///
  /// Returns whether the version follows the API changes.
  ///
  /// Throws an `InvalidUsageException` outside of a Git repository and an
  /// `UnavailableException` when Git is missing.
  Future<bool> runSemverGate(InspectraConfig config) async {
    final SemverResult result = await checkSemver(
      config,
      packageRoot,
      GitHistory(
        processRunner: context.processRunner,
        workingDirectory: packageRoot,
      ),
    );
    out.writeln(result.render());
    return !result.failed;
  }

  /// Runs the API check and reports whether it passed.
  ///
  /// Returns `true` when the public API matches its dump.
  Future<bool> runApiCheck(InspectraConfig config) async {
    final ApiCheckResult result = await checkApi(config, packageRoot);
    out.writeln(result.render());
    return !result.failed;
  }

  /// Provisions Trivy, runs [scans] (or every enabled scan) and reports
  /// whether all of them passed.
  ///
  /// Returns `true` when no scan failed.
  ///
  /// Throws a [TrivyException] when Trivy is not available.
  Future<bool> runScans(InspectraConfig config, {Set<TrivyScan>? scans}) async {
    final String executable = await provisionTrivy(config);
    final List<ScanResult> results = baselineScans(
      await runTrivyScans(
        config,
        packageRoot,
        only: scans,
        executable: executable,
      ),
      baselineMatcher(config),
    );
    for (final result in results) {
      out.writeln(result.render());
    }
    return results.every((result) => !result.failed);
  }

  /// Makes Trivy available as configured: an explicit executable, an
  /// installed or cached binary, or a verified download.
  ///
  /// Returns the executable.
  ///
  /// Throws a [TrivyException] with the reason when Trivy is unavailable.
  Future<String> provisionTrivy(InspectraConfig config) async {
    final console = Console(
      out: context.out,
      err: context.err,
      styler: const AnsiStyler(enabled: false),
    );
    final session = CommandSession(
      context: context,
      config: config,
      console: console,
      cliIgnores: const <String>[],
      workingDirectory: packageRoot,
    );
    try {
      final TrivyProvision provision = await session
          .trivyProvisioner()
          .provision(onStatus: console.info);
      return switch (provision) {
        TrivyAvailable(:final executable) => executable,
        TrivyUnavailable(:final reason) => throw TrivyException(reason),
      };
    } finally {
      session.close();
    }
  }

  /// Runs the format check and reports whether it passed; [fix] formats
  /// the files instead.
  ///
  /// Returns `true` when the check passed.
  Future<bool> runFormat(InspectraConfig config, {bool fix = false}) async {
    final FormatResult result = await runFormatCheck(
      config,
      packageRoot,
      fix: fix,
    );
    out.writeln(result.render());
    return !result.failed;
  }

  /// Runs the lint check and reports whether it passed; [fix] applies
  /// `dart fix --apply` first.
  ///
  /// Returns `true` when the check passed.
  Future<bool> runLintGate(InspectraConfig config, {bool fix = false}) async {
    final LintResult result = baselineLint(
      await runLintCheck(config, packageRoot, fix: fix),
      baselineMatcher(config),
    );
    out.writeln(result.render());
    return !result.failed;
  }

  /// Runs the coverage gate and reports whether it passed;
  /// [minLineCoverage] overrides the configured threshold.
  ///
  /// Returns `true` when the gate passed.
  Future<bool> runCoverageGate(
    InspectraConfig config, {
    double? minLineCoverage,
  }) async {
    final CoverageReport report = await runCoverage(
      config.coverage,
      packageRoot,
      minLineCoverage: minLineCoverage,
    );
    out.writeln(report.render());
    return !report.failed;
  }
}
