import 'dart:convert';
import 'dart:io';

import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/quality/format_check.dart';
import 'package:inspectra/src/quality/lint.dart';
import 'package:inspectra/src/util/files.dart';
import 'package:path/path.dart' as p;

/// Where the command line writes the JSON reports of the format and lint
/// checks, relative to the package root.
const qualityReportDirectory = '.dart_tool/inspectra';

/// Checks - or with [fix], applies - the formatting of the package in
/// [packageRoot], straight from the filesystem, and writes
/// `.dart_tool/inspectra/format.json`.
Future<FormatResult> runFormatCheck(
  InspectraConfig config,
  String packageRoot, {
  bool fix = false,
}) async {
  final FormatConfig format = config.format;
  final FormatResult result = await checkFormat(
    config: format,
    packageRoot: packageRoot,
    files: listFiles(packageRoot, format.include, format.exclude),
    fix: fix,
  );
  await _writeReport(packageRoot, 'format', result.toJson());
  return result;
}

/// Analyzes the package in [packageRoot] - after `dart fix --apply` with
/// [fix] - and writes `.dart_tool/inspectra/lint.json`.
Future<LintResult> runLintCheck(
  InspectraConfig config,
  String packageRoot, {
  bool fix = false,
}) async {
  final LintResult result = await runLint(
    config: config.lint,
    packageRoot: packageRoot,
    fix: fix,
  );
  await _writeReport(packageRoot, 'lint', result.toJson());
  return result;
}

Future<void> _writeReport(
  String packageRoot,
  String name,
  Map<String, Object?> json,
) async {
  final file = File(p.join(packageRoot, qualityReportDirectory, '$name.json'));
  await file.parent.create(recursive: true);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
}
