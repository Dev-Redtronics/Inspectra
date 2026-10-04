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
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/inspectra_command.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/policy/filter_outcome.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/trivy/configured_scans_report.dart';
import 'package:inspectra/src/trivy/finding.dart';
import 'package:inspectra/src/trivy/trivy_command.dart';
import 'package:inspectra/src/trivy/trivy_command_report.dart';
import 'package:inspectra/src/trivy/trivy_exception.dart';
import 'package:inspectra/src/trivy/trivy_outcome.dart';
import 'package:inspectra/src/trivy/trivy_provision.dart';

/// `inspectra trivy [scans...]`: runs Trivy, locating or downloading it as
/// configured.
///
/// * With scan names (`secret`, `license`, `vulnerability`, `filesystem`) or
///   with `trivy.enabled: true`, the configured scans run, each with its own
///   settings and JSON report in `trivy.report_directory`.
/// * Otherwise one `trivy fs` scan of the package runs with the scanners of
///   `trivy.filesystem`.
/// * `--install` and `--where` only provision Trivy and report it.
final class TrivyCommand extends InspectraCommand {
  /// Creates the command.
  TrivyCommand(super.context) : super(withTrivyOptions: true) {
    argParser
      ..addFlag(
        'install',
        negatable: false,
        help: 'Only make Trivy available (for example to warm a CI cache).',
      )
      ..addFlag(
        'where',
        negatable: false,
        help:
            'Only print which Trivy executable would be used, '
            'without downloading one.',
      );
  }

  /// The command name.
  @override
  String get name => 'trivy';

  /// The one line description.
  @override
  String get description =>
      'Run Trivy: the configured scans, or a filesystem scan of the package.';

  /// The positional arguments.
  @override
  String get invocation {
    final String scans = TrivyScan.values.map((scan) => scan.name).join('|');
    return 'inspectra trivy [$scans...] [options]';
  }

  /// Provisions and runs Trivy.
  ///
  /// Returns the report.
  ///
  /// Throws an [InvalidUsageException] for unknown scan names, an
  /// [UnavailableException] when `--install`, `--where` or the configured
  /// scans find no usable Trivy or Trivy fails, and an
  /// [InvalidInputException] when the package has not been resolved.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    final String root = session.workingDirectory;
    final String display = session.display(root);
    final Set<TrivyScan> named = _scans(results.rest);
    final install = results['install'] == true;
    final bool provisionOnly = install || results['where'] == true;
    if (provisionOnly) {
      final TrivyProvision provision = await session
          .trivyProvisioner()
          .provision(onStatus: session.console.info, allowDownload: install);
      if (provision case TrivyUnavailable(:final reason)) {
        throw UnavailableException(reason);
      }
      return TrivyCommandReport(
        target: display,
        outcome: TrivyOutcome(provision: provision, findings: const []),
        findings: const <Finding>[],
        provisionOnly: true,
      );
    }
    if (named.isNotEmpty || session.config.trivy.enabled) {
      return _configuredScans(session, named);
    }
    final TrivyOutcome outcome = await session.trivyService().scan(
      root,
      displayPrefix: display,
      onStatus: session.console.info,
    );
    final FilterOutcome filtered = session.filter().apply(outcome.findings);
    return TrivyCommandReport(
      target: display,
      outcome: outcome,
      findings: filtered.kept,
    );
  }

  /// Runs the configured scans, or only the [named] ones.
  ///
  /// Returns the report.
  ///
  /// Throws an [UnavailableException] when Trivy is unavailable or fails,
  /// and an [InvalidInputException] when `pubspec.lock` or the package
  /// configuration is missing.
  Future<CommandReport> _configuredScans(
    CommandSession session,
    Set<TrivyScan> named,
  ) async {
    final TrivyProvision provision = await session.trivyProvisioner().provision(
      onStatus: session.console.info,
    );
    final outcome = TrivyOutcome(provision: provision, findings: const []);
    switch (provision) {
      case TrivyUnavailable(:final reason):
        throw UnavailableException(reason);
      case TrivyAvailable(:final executable):
        try {
          final List<ScanResult> scanResults = await runTrivyScans(
            session.config,
            session.workingDirectory,
            only: named.isEmpty ? null : named,
            executable: executable,
          );
          return ConfiguredScansReport(results: scanResults, outcome: outcome);
        } on TrivyException catch (error) {
          throw UnavailableException(error.message);
        } on FileSystemException catch (error) {
          throw InvalidInputException(_describe(error));
        }
    }
  }

  /// Describes [error] as one sentence: its message and, when known, the
  /// path it is about.
  ///
  /// Returns the description.
  String _describe(FileSystemException error) {
    final String? path = error.path;
    if (path == null) {
      return error.message;
    }
    return '${error.message} ($path)';
  }

  /// Parses the scan names in [arguments].
  ///
  /// Returns the selected scans.
  ///
  /// Throws an [InvalidUsageException] for unknown names.
  Set<TrivyScan> _scans(List<String> arguments) {
    final scans = <TrivyScan>{};
    for (final argument in arguments) {
      final Iterable<TrivyScan> scan = TrivyScan.values.where(
        (s) => s.name == argument,
      );
      if (scan.isEmpty) {
        throw InvalidUsageException(
          'Unknown scan "$argument". Known scans: '
          '${TrivyScan.values.map((s) => s.name).join(', ')}.',
        );
      }
      scans.add(scan.first);
    }
    return scans;
  }
}
