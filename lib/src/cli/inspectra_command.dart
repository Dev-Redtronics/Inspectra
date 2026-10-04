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

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../config/config_loader.dart';
import '../io/ansi_styler.dart';
import '../io/console.dart';
import '../io/verbosity.dart';
import '../model/inspectra_exception.dart';
import '../model/severity.dart';
import '../report/command_report.dart';
import '../report/output_format.dart';
import '../report/report_renderer.dart';
import 'command_context.dart';
import 'command_session.dart';
import 'exit_code.dart';
import 'shared_options.dart';

/// The base of every Inspectra command.
///
/// It owns the life cycle that all commands share: parse the shared options,
/// load and validate the configuration, run the command, render the report
/// in the requested format to standard output or a file, and translate the
/// outcome into an exit code. Subclasses only implement [execute].
abstract class InspectraCommand extends Command<int> {
  /// Creates a command running in [context]; [withTrivyOptions] adds the
  /// Trivy flags.
  InspectraCommand(this.context, {bool withTrivyOptions = false}) {
    SharedOptions.addTo(argParser);
    if (withTrivyOptions) {
      SharedOptions.addTrivyTo(argParser);
    }
  }

  /// The outside world.
  final CommandContext context;

  /// The severity that fails the command when `failOn` is not configured.
  Severity get defaultFailOn => Severity.unknown;

  /// Runs the command logic.
  ///
  /// [session] provides configuration and services and [results] the
  /// parsed arguments.
  ///
  /// Returns the report to render.
  Future<CommandReport> execute(CommandSession session, ArgResults results);

  /// Prints the usage to standard output of the [context].
  @override
  void printUsage() => context.out.writeln(usage);

  /// Runs the shared life cycle.
  ///
  /// Returns the process exit code.
  @override
  Future<int> run() async {
    final results = argResults;
    if (results == null) {
      return ExitCode.software.code;
    }
    final console = _console(results);
    CommandSession? session;
    try {
      final config =
          ConfigLoader(
            environment: context.environment,
            workingDirectory: context.workingDirectory,
          ).load(
            overrides: SharedOptions.overrides(results),
            explicitPath: results['config'] as String?,
          );
      final active = CommandSession(
        context: context,
        config: config,
        console: console,
        cliIgnores: results['ignore'] as List<String>,
      );
      session = active;
      _warnAboutExpiredRules(active);
      final report = await execute(active, results);
      return _finish(report, results, active);
    } on InspectraException catch (error) {
      console.error(error.message);
      return ExitCode.of(error).code;
    } finally {
      session?.close();
    }
  }

  /// Creates the console for the parsed [results].
  ///
  /// Returns the console.
  Console _console(ArgResults results) {
    final colorFlag = results['color'] as bool?;
    final enabled =
        colorFlag ??
        AnsiStyler.detect(
          environment: context.environment,
          noColorFlag: false,
          hasTerminal: context.outIsTerminal,
          supportsAnsi: context.supportsAnsi,
        );
    final verbosity = results['quiet'] == true
        ? Verbosity.quiet
        : results['verbose'] == true
        ? Verbosity.verbose
        : Verbosity.normal;
    return Console(
      out: context.out,
      err: context.err,
      styler: AnsiStyler(enabled: enabled),
      verbosity: verbosity,
    );
  }

  /// Warns about ignore rules whose expiry date has passed.
  void _warnAboutExpiredRules(CommandSession session) {
    final now = context.clock.now();
    for (final rule in session.config.ignore.where((r) => r.isExpired(now))) {
      final day = rule.expires?.toIso8601String().substring(0, 10);
      session.console.warning(
        'The ignore rule for ${rule.id} expired on '
        '$day and no longer suppresses findings ("${rule.reason}").',
      );
    }
  }

  /// Renders [report], writes it and decides the exit code.
  ///
  /// Returns the process exit code.
  ///
  /// Throws an [UnavailableException] when the output file cannot be
  /// written.
  int _finish(
    CommandReport report,
    ArgResults results,
    CommandSession session,
  ) {
    final format = OutputFormat.fromId(results['format'] as String);
    final outputPath = results['output'] as String?;
    final style = outputPath == null
        ? session.console.styler
        : const AnsiStyler(enabled: false);
    final rendered = const ReportRenderer().render(
      report,
      format,
      style: style,
      generatedAt: context.clock.now(),
    );
    if (outputPath == null) {
      session.console.report(rendered);
    }
    if (outputPath != null) {
      _writeFile(session.resolve(outputPath), rendered);
      session.console.info(
        'Report written to ${session.display(session.resolve(outputPath))}',
      );
    }
    final threshold = session.config.failOn ?? defaultFailOn;
    if (!report.isFailing(threshold) || results['exit-zero'] == true) {
      return ExitCode.success.code;
    }
    return ExitCode.findings.code;
  }

  /// Writes [content] to [path], creating parent directories.
  ///
  /// Throws an [UnavailableException] when the file cannot be written.
  void _writeFile(String path, String content) {
    try {
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    } on FileSystemException catch (error) {
      throw UnavailableException(
        'Cannot write the report to $path: '
        '${error.message}',
      );
    }
  }
}
