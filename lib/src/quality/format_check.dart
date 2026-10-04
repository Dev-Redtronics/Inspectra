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
import 'package:inspectra/src/quality/format_result.dart';
import 'package:inspectra/src/util/dart_tool.dart';
import 'package:path/path.dart' as p;

export 'package:inspectra/src/quality/format_result.dart';

/// How many files are passed to one `dart format` process, which keeps the
/// command line below the length limits of every platform.
const _filesPerProcess = 100;

/// The line `dart format` prints for every file it would change (`Changed`)
/// or did change (`Formatted`) - but not its closing summary line,
/// `Formatted 2 files (1 changed) in 0.01 seconds.`.
final _changedLine = RegExp(
  r'^(?:Changed|Formatted) (?!\d+ files? \()(.+)$',
  multiLine: true,
);

/// Checks - or with [fix], applies - the formatting of [files], paths
/// relative to [packageRoot], with `dart format`.
///
/// `dart format` runs in the package root, so it picks up the language version
/// of the package and the `formatter` section of `analysis_options.yaml`, just
/// like running it by hand.
Future<FormatResult> checkFormat({
  required FormatConfig config,
  required String packageRoot,
  required List<String> files,
  bool fix = false,
}) async {
  final changed = <String>[];
  final sorted = [...files]..sort();
  for (var start = 0; start < sorted.length; start += _filesPerProcess) {
    final List<String> batch = sorted.sublist(
      start,
      start + _filesPerProcess > sorted.length
          ? sorted.length
          : start + _filesPerProcess,
    );
    final ProcessResult result = await runDart([
      'format',
      if (!fix) ...['--output=none', '--set-exit-if-changed'],
      if (config.pageWidth != null) '--page-width=${config.pageWidth}',
      ...batch,
    ], workingDirectory: packageRoot);

    if (result.exitCode != 0 && result.exitCode != 1) {
      throw DartToolException(
        '"dart format" failed with exit code ${result.exitCode}.\n'
        '${'${result.stderr}'.trim()}',
      );
    }
    for (final RegExpMatch match in _changedLine.allMatches(
      '${result.stdout}',
    )) {
      changed.add(p.posix.joinAll(p.split(match.group(1)!.trim())));
    }
  }
  return FormatResult(
    checked: files.length,
    unformatted: changed,
    failOnFindings: config.failOnFindings,
    fixed: fix,
  );
}
