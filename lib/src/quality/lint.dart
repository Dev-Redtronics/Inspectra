import 'dart:io';

import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/util/dart_tool.dart';
import 'package:inspectra/src/util/files.dart';

/// The exit codes `dart analyze` uses for a completed analysis: no
/// diagnostics, infos, warnings, errors.
const _completedAnalysisExitCodes = {0, 1, 2, 3};

/// One diagnostic reported by `dart analyze`.
class LintIssue {
  /// Creates a diagnostic.
  const LintIssue({
    required this.severity,
    required this.type,
    required this.code,
    required this.path,
    required this.line,
    required this.column,
    required this.message,
  });

  /// `error`, `warning` or `info`.
  final LintLevel severity;

  /// The kind of diagnostic, such as `LINT`, `HINT`, `STATIC_WARNING` or
  /// `COMPILE_TIME_ERROR`.
  final String type;

  /// The diagnostic or lint name, lower case, such as `prefer_single_quotes`.
  final String code;

  /// The file, relative to the package root.
  final String path;

  /// The 1-based line.
  final int line;

  /// The 1-based column.
  final int column;

  /// The analyzer's message.
  final String message;

  /// Serializes this diagnostic for the JSON report.
  Map<String, Object?> toJson() => {
    'severity': severity.name,
    'type': type,
    'code': code,
    'path': path,
    'line': line,
    'column': column,
    'message': message,
  };
}

/// The outcome of the static analysis check.
class LintResult {
  /// Creates the outcome.
  LintResult({required List<LintIssue> issues, required this.failOn})
    : issues = List.unmodifiable(
        <LintIssue>[...issues]..sort((a, b) {
          final int bySeverity = a.severity.index.compareTo(b.severity.index);
          if (bySeverity != 0) {
            return bySeverity;
          }
          final int byPath = a.path.compareTo(b.path);
          if (byPath != 0) {
            return byPath;
          }
          final int byLine = a.line.compareTo(b.line);
          return byLine != 0 ? byLine : a.column.compareTo(b.column);
        }),
      );

  /// Every diagnostic, errors first, then by file and position.
  final List<LintIssue> issues;

  /// The lowest severity that fails the check.
  final LintLevel failOn;

  /// The diagnostics that fail the check.
  Iterable<LintIssue> get failing =>
      issues.where((issue) => issue.severity.index <= failOn.index);

  /// Whether the check failed.
  bool get failed => failOn != LintLevel.none && failing.isNotEmpty;

  /// A readable summary for the console or the build log.
  String render() {
    if (issues.isEmpty) {
      return 'Lint: no issues found.';
    }
    String count(LintLevel level) =>
        '${issues.where((issue) => issue.severity == level).length} '
        '${level.name}(s)';
    final suffix = failed ? '' : ' (not failing)';
    final String counts = [
      LintLevel.error,
      LintLevel.warning,
      LintLevel.info,
    ].map(count).join(', ');
    return [
      'Lint: ${issues.length} issue(s) - $counts$suffix.',
      for (final issue in issues) _render(issue),
    ].join('\n');
  }

  static String _render(LintIssue issue) {
    final String level = issue.severity.name.toUpperCase();
    final location = '${issue.path}:${issue.line}:${issue.column}';
    return '  [$level] $location: ${issue.code} - ${issue.message}';
  }

  /// Serializes this result for the JSON report.
  Map<String, Object?> toJson() => {
    'check': 'lint',
    'failed': failed,
    'fail_on': failOn.name,
    'issues': [for (final issue in issues) issue.toJson()],
  };
}

/// Analyzes the package in [packageRoot] with `dart analyze`, after applying
/// `dart fix --apply` when [fix] is set.
///
/// The analysis honours the package's `analysis_options.yaml`: its lint
/// rules, its `analyzer: exclude` and its severity changes.
Future<LintResult> runLint({
  required LintConfig config,
  required String packageRoot,
  bool fix = false,
}) async {
  if (fix) {
    final ProcessResult fixed = await runDart([
      'fix',
      '--apply',
    ], workingDirectory: packageRoot);
    if (fixed.exitCode != 0) {
      throw DartToolException(
        '"dart fix --apply" failed with exit code ${fixed.exitCode}.\n'
        '${'${fixed.stderr}'.trim()}',
      );
    }
  }

  final ProcessResult result = await runDart([
    'analyze',
    '--format=machine',
    '.',
  ], workingDirectory: packageRoot);
  if (!_completedAnalysisExitCodes.contains(result.exitCode)) {
    throw DartToolException(
      '"dart analyze" failed with exit code ${result.exitCode}.\n'
      '${'${result.stderr}'.trim()}${'${result.stdout}'.trim()}',
    );
  }
  return LintResult(
    issues: parseAnalyzerOutput(
      '${result.stdout}${result.stderr}',
      packageRoot,
    ),
    failOn: config.failOn,
  );
}

/// Reads the diagnostics of `dart analyze --format=machine`.
///
/// Each diagnostic is one line of `|`-separated fields, in which a `|` or `\`
/// inside a field is escaped with a backslash. Lines that are not diagnostics
/// are ignored. Paths are made relative to [packageRoot].
List<LintIssue> parseAnalyzerOutput(String output, String packageRoot) {
  final issues = <LintIssue>[];
  for (final String line in output.split('\n')) {
    final List<String> fields = _splitMachineLine(line.trimRight());
    if (fields.length < 8) {
      continue;
    }
    final LintLevel? severity = switch (fields[0]) {
      'ERROR' => LintLevel.error,
      'WARNING' => LintLevel.warning,
      'INFO' => LintLevel.info,
      _ => null,
    };
    final int? lineNumber = int.tryParse(fields[4]);
    final int? column = int.tryParse(fields[5]);
    if (severity == null || lineNumber == null || column == null) {
      continue;
    }
    issues.add(
      LintIssue(
        severity: severity,
        type: fields[1],
        code: fields[2].toLowerCase(),
        path: posixRelative(fields[3], from: packageRoot),
        line: lineNumber,
        column: column,
        message: fields.sublist(7).join('|'),
      ),
    );
  }
  return issues;
}

List<String> _splitMachineLine(String line) {
  final fields = <String>[];
  final current = StringBuffer();
  var escaped = false;
  for (final int unit in line.codeUnits) {
    final char = String.fromCharCode(unit);
    if (escaped) {
      current.write(char);
      escaped = false;
    } else if (char == r'\') {
      escaped = true;
    } else if (char == '|') {
      fields.add(current.toString());
      current.clear();
    } else {
      current.write(char);
    }
  }
  fields.add(current.toString());
  return fields;
}
