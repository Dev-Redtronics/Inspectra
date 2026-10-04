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

/// Writes [json] as the report [name] into the quality report directory of
/// the package in [packageRoot], creating the directory when needed.
Future<void> _writeReport(
  String packageRoot,
  String name,
  Map<String, Object?> json,
) async {
  final file = File(p.join(packageRoot, qualityReportDirectory, '$name.json'));
  await file.parent.create(recursive: true);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
}
