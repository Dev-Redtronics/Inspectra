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

import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/quality/lint_issue.dart';
import 'package:inspectra/src/quality/lint_result.dart';
import 'package:inspectra/src/util/dart_tool.dart';
import 'package:inspectra/src/util/files.dart';

export 'package:inspectra/src/quality/lint_issue.dart';
export 'package:inspectra/src/quality/lint_result.dart';

/// The exit codes `dart analyze` uses for a completed analysis: no
/// diagnostics, infos, warnings, errors.
const _completedAnalysisExitCodes = {0, 1, 2, 3};

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
    final LintLevel? severity = _analyzerSeverities[fields[0]];
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

/// The lint levels of the severities in `dart analyze --format=machine`.
const _analyzerSeverities = <String, LintLevel>{
  'ERROR': LintLevel.error,
  'WARNING': LintLevel.warning,
  'INFO': LintLevel.info,
};

/// Splits a line of `dart analyze --format=machine` into its `|`-separated
/// fields, honouring backslash escapes inside a field.
List<String> _splitMachineLine(String line) {
  final fields = <String>[];
  final current = StringBuffer();
  var escaped = false;
  for (final int unit in line.codeUnits) {
    final char = String.fromCharCode(unit);
    if (escaped) {
      current.write(char);
      escaped = false;
      continue;
    }
    if (char == r'\') {
      escaped = true;
      continue;
    }
    if (char == '|') {
      fields.add(current.toString());
      current.clear();
      continue;
    }
    current.write(char);
  }
  fields.add(current.toString());
  return fields;
}
