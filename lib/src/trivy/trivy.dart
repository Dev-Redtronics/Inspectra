import 'dart:convert';
import 'dart:io';

import 'package:inspectra/src/config/severity.dart';
import 'package:path/path.dart' as p;

/// The environment variable that overrides the configured Trivy executable.
const trivyExecutableVariable = 'INSPECTRA_TRIVY';

/// Thrown when Trivy is missing or fails, as opposed to reporting findings.
class TrivyException implements Exception {
  /// Creates the exception.
  const TrivyException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => message;
}

/// Runs the Trivy command line.
class Trivy {
  /// Uses the executable named by `INSPECTRA_TRIVY`, else [executable], else
  /// `trivy` from the `PATH`, and runs it in [workingDirectory].
  Trivy({
    String? executable,
    Map<String, String>? environment,
    this.workingDirectory,
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

/// The parts of a Trivy JSON report Inspectra reads.
class TrivyReport {
  /// Creates a report from its results.
  const TrivyReport(this.results);

  /// Parses the output of `trivy --format json`.
  factory TrivyReport.parse(String json) {
    final Object? decoded = jsonDecode(json);
    final Object? results = decoded is Map ? decoded['Results'] : null;
    return TrivyReport([
      if (results is List)
        for (final result in results)
          if (result is Map<String, Object?>) TrivyResult(result),
    ]);
  }

  /// One entry per scanned target.
  final List<TrivyResult> results;
}

/// The findings for one target of a Trivy report.
class TrivyResult {
  /// Wraps the decoded JSON of one result.
  const TrivyResult(this._json);

  final Map<String, Object?> _json;

  /// The scanned file, relative to the scan target.
  String get target => _string(_json, 'Target');

  /// The secrets found in [target].
  List<Map<String, Object?>> get secrets => _entries('Secrets');

  /// The vulnerabilities found in [target].
  List<Map<String, Object?>> get vulnerabilities => _entries('Vulnerabilities');

  /// The licenses found in [target].
  List<Map<String, Object?>> get licenses => _entries('Licenses');

  /// The misconfigurations found in [target].
  List<Map<String, Object?>> get misconfigurations =>
      _entries('Misconfigurations');

  List<Map<String, Object?>> _entries(String key) {
    final Object? value = _json[key];
    if (value is! List) {
      return const [];
    }
    return [
      for (final entry in value)
        if (entry is Map<String, Object?>) entry,
    ];
  }
}

/// The string at [key] of a Trivy JSON object, or the empty string.
String trivyString(Map<String, Object?> json, String key) => _string(json, key);

/// The severity at `Severity` of a Trivy JSON object.
Severity trivySeverity(Map<String, Object?> json) =>
    Severity.tryParse(_string(json, 'Severity')) ?? Severity.unknown;

String _string(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  return value == null ? '' : '$value';
}
