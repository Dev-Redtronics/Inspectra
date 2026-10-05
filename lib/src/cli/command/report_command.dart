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
import 'package:inspectra/src/cli/command/config_tool_command.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/dashboard/report_merge.dart';
import 'package:inspectra/src/dashboard/report_runner.dart';
import 'package:inspectra/src/dashboard/report_step.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/aggregate_report.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/report/output_format.dart';
import 'package:inspectra/src/report/report_renderer.dart';
import 'package:path/path.dart' as p;

/// `inspectra report`: runs every evaluation of the project and reports all
/// of them at once, for example as one HTML dashboard.
///
/// A section that cannot run completely is reported with its cause, the
/// others still run, and the command exits with `69` after writing the
/// report. `--merge` combines JSON reports of earlier runs instead.
final class ReportCommand extends ConfigToolCommand {
  /// Creates the command with its `--skip`, `--also` and `--merge` options.
  ReportCommand(super.context) {
    argParser
      ..addMultiOption(
        'skip',
        help: 'Leave out these sections, such as "scan,coverage".',
        allowed: <String>[for (final step in ReportStep.values) step.id],
        valueHelp: 'section',
      )
      ..addMultiOption(
        'also',
        help:
            'Also write the report in another format, such as '
            '"junit=build/junit.xml"; repeatable.',
        valueHelp: 'format=path',
        splitCommas: false,
      )
      ..addMultiOption(
        'merge',
        help:
            'Merge these JSON reports instead of running the evaluations; '
            'repeatable.',
        valueHelp: 'report.json',
        splitCommas: false,
      );
  }

  /// The command name.
  @override
  String get name => 'report';

  /// The one line description.
  @override
  String get description =>
      'Run every evaluation - supply chain, dependencies, configuration, '
      'format, lint, style, API, changelog, Trivy and coverage - and report '
      'them at once, for example as an HTML dashboard.';

  /// Runs the evaluations, or merges reports, and writes the additional
  /// formats.
  ///
  /// Returns the report.
  ///
  /// Throws an [InvalidUsageException] for a malformed `--also` and an
  /// [InvalidInputException] for a report to merge that cannot be read.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    final also = <(OutputFormat, String)>[
      for (final String value in results['also'] as List<String>)
        _parseAlso(value),
    ];
    final merge = results['merge'] as List<String>;
    final Severity failOn = session.config.failOn ?? defaultFailOn;
    final AggregateReport report = merge.isEmpty
        ? await ReportRunner(
            session: session,
            configLint: () => lintReport(session, results),
            skip: <ReportStep>{
              for (final String id in results['skip'] as List<String>)
                ?ReportStep.tryParse(id),
            },
          ).run()
        : mergeReports(<(String, String)>[
            for (final String path in merge) _read(session, path),
          ], failOn);
    for (final (OutputFormat format, String path) in also) {
      final String rendered = const ReportRenderer().render(
        report,
        format,
        style: const AnsiStyler(enabled: false),
        generatedAt: context.clock.now(),
        failOn: failOn,
      );
      writeOutput(session.resolve(path), rendered);
      session.console.info(
        'Report written to ${session.display(session.resolve(path))}',
      );
    }
    return report;
  }

  /// Parses the `--also` [value] `format=path`.
  ///
  /// Returns the format and the path.
  ///
  /// Throws an [InvalidUsageException] when [value] names no format or no
  /// path.
  (OutputFormat, String) _parseAlso(String value) {
    final int separator = value.indexOf('=');
    final String id = separator < 0 ? value : value.substring(0, separator);
    final OutputFormat? format = OutputFormat.values
        .where((format) => format.id == id)
        .firstOrNull;
    final String path = separator < 0 ? '' : value.substring(separator + 1);
    if (format == null || format == OutputFormat.text || path.isEmpty) {
      final String formats = OutputFormat.values
          .where((format) => format != OutputFormat.text)
          .map((format) => format.id)
          .join(', ');
      throw InvalidUsageException(
        'Invalid --also "$value": expected <format>=<path> with one of '
        '$formats.',
      );
    }
    return (format, path);
  }

  /// Reads the report at [path] to merge.
  ///
  /// Returns its file name and content.
  ///
  /// Throws an [InvalidInputException] when it cannot be read.
  (String, String) _read(CommandSession session, String path) {
    final String resolved = session.resolve(path);
    try {
      return (p.basename(resolved), File(resolved).readAsStringSync());
    } on FileSystemException catch (error) {
      throw InvalidInputException(
        'Cannot read the report ${session.display(resolved)}: '
        '${error.message}',
      );
    }
  }
}
