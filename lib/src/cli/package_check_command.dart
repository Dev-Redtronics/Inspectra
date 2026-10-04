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

import 'package:args/command_runner.dart';
import 'package:inspectra/src/api/api_command.dart';
import 'package:inspectra/src/cli/command_context.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/exit_code.dart';
import 'package:inspectra/src/config/config_loader.dart';
import 'package:inspectra/src/config/config_overrides.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/coverage/coverage_gate.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/io/console.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/quality/format_check.dart';
import 'package:inspectra/src/quality/lint.dart';
import 'package:inspectra/src/quality/quality_command.dart';
import 'package:inspectra/src/trivy/finding.dart';
import 'package:inspectra/src/trivy/trivy.dart';
import 'package:inspectra/src/trivy/trivy_command.dart';
import 'package:inspectra/src/trivy/trivy_provision.dart';
import 'package:inspectra/src/util/dart_tool.dart';
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
  /// Creates a command running in [context].
  PackageCheckCommand(this.context);

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

  /// Reads the configuration of the package, with `INSPECTRA_*`
  /// environment variables layered on top.
  ///
  /// Returns the configuration.
  ///
  /// Throws a [FileSystemException] without `pubspec.yaml` and an
  /// [InspectraConfigException] for invalid configuration.
  InspectraConfig loadPackageConfig() => loadConfig(
    packageRoot,
    overrides: ConfigOverrides(environment: context.environment),
  );

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
    final List<ScanResult> results = await runTrivyScans(
      config,
      packageRoot,
      only: scans,
      executable: executable,
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
    final LintResult result = await runLintCheck(config, packageRoot, fix: fix);
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
