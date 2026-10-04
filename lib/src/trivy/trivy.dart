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

import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/trivy/trivy_exception.dart';
import 'package:inspectra/src/trivy/trivy_report.dart';
import 'package:path/path.dart' as p;

export 'package:inspectra/src/trivy/trivy_exception.dart';
export 'package:inspectra/src/trivy/trivy_report.dart';
export 'package:inspectra/src/trivy/trivy_result.dart';

/// The environment variable that overrides the configured Trivy executable.
const trivyExecutableVariable = 'INSPECTRA_TRIVY';

/// The Trivy arguments that keep a scan from opening any connection: no
/// database update and no remote lookups during the scan.
const offlineArguments = <String>['--skip-db-update', '--offline-scan'];

/// Runs the Trivy command line.
class Trivy {
  /// Uses the executable named by `INSPECTRA_TRIVY`, else [executable], else
  /// `trivy` from the `PATH`, and runs it in [workingDirectory]; [offline]
  /// keeps Trivy from opening any connection.
  Trivy({
    String? executable,
    Map<String, String>? environment,
    this.workingDirectory,
    this.offline = false,
  }) : executable =
           (environment ?? Platform.environment)[trivyExecutableVariable] ??
           executable ??
           'trivy';

  /// The executable this runner invokes.
  final String executable;

  /// The directory Trivy runs in, which should be the package root.
  ///
  /// Trivy reads `trivy.yaml`, `.trivyignore` and `trivy-secret.yaml` from
  /// its working directory unless told otherwise, so running it in the
  /// package root makes those files apply to the package being scanned.
  /// `null` keeps the current directory.
  final String? workingDirectory;

  /// Whether every scan runs without network access, as `--offline` and
  /// `network.offline` promise.
  ///
  /// Trivy is then started with `--skip-db-update` and `--offline-scan`, so
  /// it neither downloads its vulnerability database nor queries remote
  /// registries. Without a cached database the vulnerability scan fails
  /// with a [TrivyException] instead of silently going online.
  final bool offline;

  /// Runs `trivy fs` on [target] and returns the parsed JSON report.
  ///
  /// Findings never make this throw: they are in the report. A non-zero exit
  /// is a failure of Trivy itself and throws a [TrivyException].
  Future<TrivyReport> scanFilesystem({
    required String target,
    required List<String> scanners,
    required List<Severity> severity,
    List<String> arguments = const [],
  }) async {
    final Directory temporary = await Directory.systemTemp.createTemp(
      'inspectra_trivy_report',
    );
    try {
      final String reportFile = p.join(temporary.path, 'report.json');
      final List<String> commandLine = [
        'fs',
        '--quiet',
        '--scanners',
        scanners.join(','),
        '--severity',
        severity.map((level) => level.trivyName).join(','),
        '--format',
        'json',
        '--output',
        reportFile,
        if (offline) ...offlineArguments,
        ...arguments,
        target,
      ];

      final ProcessResult result;
      try {
        result = await Process.run(
          executable,
          commandLine,
          workingDirectory: workingDirectory,
        );
      } on ProcessException catch (error) {
        throw TrivyException(
          'Could not start Trivy ("$executable"): ${error.message}\n'
          'Install it '
          '(https://trivy.dev/latest/getting-started/installation/), or point '
          '"trivy.executable" or the $trivyExecutableVariable environment '
          'variable at it.',
        );
      }
      if (result.exitCode != 0) {
        throw TrivyException(
          'Trivy did not finish scanning $target: it exited with '
          '${result.exitCode}. This is a failure of Trivy itself, not a '
          'finding.\n'
          '${'${result.stderr}'.trim()}',
        );
      }
      return TrivyReport.parse(await File(reportFile).readAsString());
    } finally {
      await temporary.delete(recursive: true);
    }
  }
}

/// The string at [key] of a Trivy JSON object, or the empty string.
String trivyString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  return value == null ? '' : '$value';
}

/// The severity at `Severity` of a Trivy JSON object.
Severity trivySeverity(Map<String, Object?> json) =>
    Severity.tryParse(trivyString(json, 'Severity')) ?? Severity.unknown;
