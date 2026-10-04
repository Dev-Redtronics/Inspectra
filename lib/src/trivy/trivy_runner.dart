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

import 'dart:convert';
import 'dart:io';

import 'package:inspectra/src/config/filesystem_scan_config.dart';
import 'package:inspectra/src/config/trivy_config.dart';
import 'package:inspectra/src/io/process_outcome.dart';
import 'package:inspectra/src/io/process_runner.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/trivy/trivy_report_mapper.dart';

/// Runs `trivy fs` on a project directory and maps its JSON report.
///
/// Trivy is always started with `--exit-code 0`, so any other exit code is a
/// failure of Trivy itself and never mistaken for a finding.
final class TrivyRunner {
  /// Creates a runner; [offline] keeps Trivy from opening any connection.
  const TrivyRunner({
    required this.config,
    required this.processRunner,
    this.offline = false,
  });

  /// The Trivy configuration.
  final TrivyConfig config;

  /// Starts the Trivy process.
  final ProcessRunner processRunner;

  /// Whether the scan runs without network access, as `--offline` and
  /// `network.offline` promise.
  ///
  /// Trivy is then started with `--skip-db-update` and `--offline-scan`.
  /// Without a cached database Trivy fails, which surfaces as an
  /// [UnavailableException]: skipped in `auto` mode, exit code `69` in
  /// `required` mode.
  final bool offline;

  /// Builds the Trivy command line for scanning [directory]. Scanners,
  /// severities and skipped directories come from `trivy.filesystem`.
  ///
  /// Returns the arguments.
  List<String> arguments(String directory) {
    final FilesystemScanConfig filesystem = config.filesystem;
    final String? dbRepository = config.dbRepository;
    final String? cacheDirectory = config.cacheDirectory;
    return <String>[
      'fs',
      '--format',
      'json',
      '--quiet',
      '--exit-code',
      '0',
      '--scanners',
      filesystem.scanners.join(','),
      '--severity',
      filesystem.severity.map((severity) => severity.trivyName).join(','),
      for (final directory in filesystem.skipDirectories) ...<String>[
        '--skip-dirs',
        directory,
      ],
      '--timeout',
      '${config.timeout.inSeconds}s',
      if (config.skipDbUpdate || offline) '--skip-db-update',
      if (offline) '--offline-scan',
      if (dbRepository != null) ...<String>['--db-repository', dbRepository],
      if (cacheDirectory != null) ...<String>['--cache-dir', cacheDirectory],
      ...config.extraArgs,
      directory,
    ];
  }

  /// Scans [directory] with the Trivy [executable]; finding paths are
  /// prefixed with [displayPrefix].
  ///
  /// Returns the findings.
  ///
  /// Throws an [UnavailableException] when Trivy cannot be started, fails or
  /// produces unreadable output.
  Future<List<Finding>> scan(
    String executable,
    String directory, {
    required String displayPrefix,
  }) async {
    final Duration processTimeout = config.timeout + const Duration(minutes: 1);
    final (bool, String) outcome = await _run(
      executable,
      directory,
      processTimeout,
    );
    if (!outcome.$1) {
      throw UnavailableException(
        'Trivy did not finish scanning $directory: ${outcome.$2}',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(outcome.$2);
    } on FormatException {
      throw const UnavailableException(
        'Trivy produced output that is not '
        'valid JSON.',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const UnavailableException(
        'Trivy produced an unexpected JSON '
        'document.',
      );
    }
    return TrivyReportMapper(pathPrefix: displayPrefix).map(decoded);
  }

  /// Starts Trivy and collects its output.
  ///
  /// Returns whether it succeeded and either its standard output or the
  /// failure description.
  Future<(bool, String)> _run(
    String executable,
    String directory,
    Duration timeout,
  ) async {
    try {
      final ProcessOutcome outcome = await processRunner.run(
        executable,
        arguments(directory),
        timeout: timeout,
      );
      if (outcome.succeeded) {
        return (true, outcome.stdout);
      }
      final List<String> lines = outcome.stderr.trim().split('\n');
      final Iterable<String> tail = lines.skip(
        lines.length > 10 ? lines.length - 10 : 0,
      );
      return (false, 'exit code ${outcome.exitCode}\n${tail.join('\n')}');
    } on ProcessException catch (error) {
      return (false, error.message);
    }
  }
}
