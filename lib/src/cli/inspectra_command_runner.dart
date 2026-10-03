import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:inspectra/src/api/api_command.dart';
import 'package:inspectra/src/config/config_exception.dart';
import 'package:inspectra/src/config/config_loader.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/coverage/coverage_gate.dart';
import 'package:inspectra/src/quality/format_check.dart';
import 'package:inspectra/src/quality/lint.dart';
import 'package:inspectra/src/quality/quality_command.dart';
import 'package:inspectra/src/trivy/finding.dart';
import 'package:inspectra/src/trivy/trivy.dart';
import 'package:inspectra/src/trivy/trivy_command.dart';
import 'package:inspectra/src/util/dart_tool.dart';

/// The exit code when a check failed.
const checkFailedExitCode = 1;

/// The exit code when the configuration or an external tool is broken.
const errorExitCode = 2;

/// The exit code for invalid command line usage.
const usageExitCode = 64;

/// The `inspectra` command line.
class InspectraCommandRunner extends CommandRunner<int> {
  /// Creates the command line, printing to [out] and [err].
  InspectraCommandRunner({StringSink? out, StringSink? err})
    : _out = out ?? stdout,
      _err = err ?? stderr,
      super(
        'inspectra',
        'Format, lint, security scans, public API validation and coverage for '
            'Dart packages.',
      ) {
    argParser.addOption(
      'directory',
      abbr: 'C',
      help: 'The package to inspect.',
      defaultsTo: '.',
      valueHelp: 'path',
    );
    addCommand(_CheckCommand());
    addCommand(_FormatCommand());
    addCommand(_LintCommand());
    addCommand(_ApiCommand());
    addCommand(_TrivyCommand());
    addCommand(_CoverageCommand());
  }

  final StringSink _out;
  final StringSink _err;

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      return await super.run(args) ?? 0;
    } on UsageException catch (error) {
      _err.writeln(error);
      return usageExitCode;
    } on InspectraConfigException catch (error) {
      _err.writeln(error);
      return errorExitCode;
    } on TrivyException catch (error) {
      _err.writeln(error);
      return errorExitCode;
    } on CoverageException catch (error) {
      _err.writeln(error);
      return errorExitCode;
    } on DartToolException catch (error) {
      _err.writeln(error);
      return errorExitCode;
    } on FileSystemException catch (error) {
      _err.writeln(error);
      return errorExitCode;
    }
  }
}

abstract class _InspectraCommand extends Command<int> {
  InspectraCommandRunner get _runner => runner! as InspectraCommandRunner;

  StringSink get out => _runner._out;

  String get packageRoot => globalResults!.option('directory')!;

  InspectraConfig loadPackageConfig() => loadConfig(packageRoot);

  /// Runs the API check and reports whether it passed.
  Future<bool> runApiCheck(InspectraConfig config) async {
    final ApiCheckResult result = await checkApi(config, packageRoot);
    out.writeln(result.render());
    return !result.failed;
  }

  /// Runs [scans] and reports whether all of them passed.
  Future<bool> runScans(InspectraConfig config, {Set<TrivyScan>? scans}) async {
    final List<ScanResult> results = await runTrivyScans(
      config,
      packageRoot,
      only: scans,
    );
    for (final result in results) {
      out.writeln(result.render());
    }
    return results.every((result) => !result.failed);
  }

  /// Runs the format check and reports whether it passed.
  Future<bool> runFormat(InspectraConfig config, {bool fix = false}) async {
    final FormatResult result = await runFormatCheck(
      config,
      packageRoot,
      fix: fix,
    );
    out.writeln(result.render());
    return !result.failed;
  }

  /// Runs the lint check and reports whether it passed.
  Future<bool> runLintGate(InspectraConfig config, {bool fix = false}) async {
    final LintResult result = await runLintCheck(config, packageRoot, fix: fix);
    out.writeln(result.render());
    return !result.failed;
  }

  /// Runs the coverage gate and reports whether it passed.
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

  int exitCodeFor({required bool passed}) => passed ? 0 : checkFailedExitCode;
}

class _CheckCommand extends _InspectraCommand {
  @override
  String get name => 'check';

  @override
  String get description =>
      'Runs every enabled check: format, lint, API, Trivy scans and coverage.';

  @override
  Future<int> run() async {
    final InspectraConfig config = loadPackageConfig();
    var passed = true;
    var ranAnything = false;
    if (config.format.enabled) {
      ranAnything = true;
      passed &= await runFormat(config);
    }
    if (config.lint.enabled) {
      ranAnything = true;
      passed &= await runLintGate(config);
    }
    if (config.api.enabled) {
      ranAnything = true;
      passed &= await runApiCheck(config);
    }
    if (config.trivy.enabled) {
      ranAnything = true;
      passed &= await runScans(config);
    }
    if (config.coverage.enabled) {
      ranAnything = true;
      passed &= await runCoverageGate(config);
    }
    if (!ranAnything) {
      out.writeln(
        'Nothing is enabled. Enable "format", "lint", "api", "trivy" or '
        '"coverage" in the Inspectra configuration.',
      );
    }
    return exitCodeFor(passed: passed);
  }
}

class _FormatCommand extends _InspectraCommand {
  _FormatCommand() {
    argParser.addFlag(
      'fix',
      negatable: false,
      help: 'Format the files instead of only checking them.',
    );
  }

  @override
  String get name => 'format';

  @override
  String get description =>
      'Checks that the Dart files are formatted, or formats them with --fix.';

  @override
  Future<int> run() async => exitCodeFor(
    passed: await runFormat(loadPackageConfig(), fix: argResults!.flag('fix')),
  );
}

class _LintCommand extends _InspectraCommand {
  _LintCommand() {
    argParser.addFlag(
      'fix',
      negatable: false,
      help: 'Apply "dart fix --apply" before analyzing.',
    );
  }

  @override
  String get name => 'lint';

  @override
  String get description =>
      'Analyzes the package with the rules of analysis_options.yaml.';

  @override
  Future<int> run() async => exitCodeFor(
    passed: await runLintGate(
      loadPackageConfig(),
      fix: argResults!.flag('fix'),
    ),
  );
}

class _ApiCommand extends _InspectraCommand {
  _ApiCommand() {
    addSubcommand(_ApiDumpCommand());
    addSubcommand(_ApiCheckCommand());
  }

  @override
  String get name => 'api';

  @override
  String get description => 'Records or checks the public API dump.';
}

class _ApiDumpCommand extends _InspectraCommand {
  @override
  String get name => 'dump';

  @override
  String get description => 'Writes the public API of the package to its dump.';

  @override
  Future<int> run() async {
    final String path = await dumpApi(loadPackageConfig(), packageRoot);
    out.writeln('Wrote the public API to $path.');
    return 0;
  }
}

class _ApiCheckCommand extends _InspectraCommand {
  @override
  String get name => 'check';

  @override
  String get description =>
      'Fails when the public API differs from its committed dump.';

  @override
  Future<int> run() async =>
      exitCodeFor(passed: await runApiCheck(loadPackageConfig()));
}

class _TrivyCommand extends _InspectraCommand {
  @override
  String get name => 'trivy';

  @override
  String get description =>
      'Runs Trivy scans: every enabled one, or the ones named.';

  @override
  String get invocation {
    final String scans = TrivyScan.values.map((scan) => scan.name).join('|');
    return '${runner!.executableName} trivy [$scans...]';
  }

  @override
  Future<int> run() async {
    final InspectraConfig config = loadPackageConfig();
    final List<String> named = argResults!.rest;
    if (named.isEmpty && !config.trivy.enabled) {
      out.writeln(
        'Trivy is disabled. Set "trivy.enabled: true" in the Inspectra '
        'configuration, or name a scan.',
      );
      return 0;
    }
    final scans = <TrivyScan>{
      for (final name in named)
        TrivyScan.values.firstWhere(
          (scan) => scan.name == name,
          orElse: () => usageException('Unknown scan "$name".'),
        ),
    };
    return exitCodeFor(
      passed: await runScans(config, scans: scans.isEmpty ? null : scans),
    );
  }
}

class _CoverageCommand extends _InspectraCommand {
  @override
  String get name => 'coverage';

  @override
  String get description =>
      'Runs the tests with coverage, writes lcov.info and checks the '
      'threshold.';

  @override
  ArgParser get argParser => _parser;
  final _parser = ArgParser()
    ..addOption(
      'min',
      help: 'Overrides coverage.min_line_coverage, in percent.',
      valueHelp: 'percent',
    );

  @override
  Future<int> run() async {
    final String? min = argResults!.option('min');
    final double? threshold = min == null ? null : double.tryParse(min);
    if (min != null &&
        (threshold == null || threshold < 0 || threshold > 100)) {
      usageException('--min must be a number between 0 and 100.');
    }
    final bool passed = await runCoverageGate(
      loadPackageConfig(),
      minLineCoverage: threshold,
    );
    return exitCodeFor(passed: passed);
  }
}
