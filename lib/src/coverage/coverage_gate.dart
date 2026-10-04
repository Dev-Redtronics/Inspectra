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

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:coverage/coverage.dart';
import 'package:glob/glob.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/coverage/coverage_exception.dart';
import 'package:inspectra/src/coverage/coverage_report.dart';
import 'package:inspectra/src/coverage/file_coverage.dart';
import 'package:inspectra/src/util/dart_tool.dart';
import 'package:inspectra/src/util/files.dart';
import 'package:path/path.dart' as p;

export 'package:inspectra/src/coverage/coverage_exception.dart';
export 'package:inspectra/src/coverage/coverage_report.dart';
export 'package:inspectra/src/coverage/file_coverage.dart';

/// Runs the tests of the package in [packageRoot] with coverage, writes
/// `lcov.info` and checks the configured threshold.
///
/// [minLineCoverage] overrides the configured threshold.
Future<CoverageReport> runCoverage(
  CoverageConfig config,
  String packageRoot, {
  double? minLineCoverage,
}) async {
  final String root = Directory(packageRoot).absolute
      .resolveSymbolicLinksSync();
  final output = Directory(p.join(root, config.outputDirectory));
  final raw = Directory(p.join(output.path, 'raw'));
  if (raw.existsSync()) {
    raw.deleteSync(recursive: true);
  }
  raw.createSync(recursive: true);

  final Map<String, HitMap> hitMaps = switch (config.runner) {
    CoverageRunner.dart => await _collectWithDart(config, root, raw),
    CoverageRunner.flutter => await _collectWithFlutter(config, root, raw),
  };

  final Resolver resolver = await Resolver.create(packagePath: root);
  final List<String> reportOn = [
    for (final directory in config.reportOn) p.join(root, directory),
  ];
  final List<Glob> excluded = [
    for (final pattern in config.exclude) Glob(pattern, context: p.posix),
  ];
  bool isReported(String path) =>
      reportOn.any((directory) => p.isWithin(directory, path)) &&
      !excluded.any((glob) => glob.matches(posixRelative(path, from: root)));

  final reported = <String, HitMap>{};
  final files = <FileCoverage>[];
  for (final MapEntry(key: source, value: hitMap) in hitMaps.entries) {
    final String? path = resolver.resolve(source);
    if (path == null || !isReported(path)) {
      continue;
    }
    reported[source] = hitMap;
    final Map<int, int> lines = hitMap.lineHits;
    files.add(
      FileCoverage(
        posixRelative(path, from: root),
        lines.length,
        lines.values.where((hits) => hits > 0).length,
      ),
    );
  }

  final Set<String> covered = {for (final file in files) file.path};
  final untested = <String>[
    for (final directory in reportOn)
      if (Directory(directory).existsSync())
        for (final entity in Directory(directory).listSync(recursive: true))
          if (entity is File &&
              entity.path.endsWith('.dart') &&
              isReported(entity.path))
            if (posixRelative(entity.path, from: root) case final path
                when !covered.contains(path) && _hasOwnCode(entity))
              path,
  ]..sort();

  final lcov = File(p.join(output.path, 'lcov.info'));
  await lcov.writeAsString(reported.formatLcov(resolver, basePath: root));

  return CoverageReport(
    files: files,
    untested: untested,
    lcovPath: posixRelative(lcov.path, from: root),
    minLineCoverage: minLineCoverage ?? config.minLineCoverage,
  );
}

/// `dart test --coverage` writes one JSON hit map per test suite, which the
/// coverage package merges, honouring `// coverage:ignore-line` and friends.
Future<Map<String, HitMap>> _collectWithDart(
  CoverageConfig config,
  String root,
  Directory raw,
) async {
  await _runTests(dartExecutable(), [
    'test',
    '--coverage=${raw.path}',
    ...config.testArguments,
  ], root);
  final Iterable<File> files = raw
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'));
  return HitMap.parseFiles(files, checkIgnoredLines: true, packagePath: root);
}

/// `flutter test --coverage` writes lcov directly, which is read back into
/// hit maps so that both runners are filtered and reported alike.
Future<Map<String, HitMap>> _collectWithFlutter(
  CoverageConfig config,
  String root,
  Directory raw,
) async {
  final String lcov = p.join(raw.path, 'lcov.info');
  await _runTests('flutter', [
    'test',
    '--coverage',
    '--coverage-path',
    lcov,
    ...config.testArguments,
  ], root);
  return parseLcov(await File(lcov).readAsString(), root);
}

/// Reads the line hits of an lcov report, keyed by `file:` URI.
///
/// Relative `SF:` paths are resolved against [root].
Map<String, HitMap> parseLcov(String lcov, String root) {
  final result = <String, HitMap>{};
  HitMap? current;
  for (final String line in lcov.split('\n').map((line) => line.trim())) {
    if (line.startsWith('SF:')) {
      final String path = p.normalize(p.join(root, line.substring(3)));
      current = result.putIfAbsent(Uri.file(path).toString(), HitMap.new);
      continue;
    }
    if (line.startsWith('DA:') && current != null) {
      final [String number, String hits, ...] = line.substring(3).split(',');
      final int lineNumber = int.parse(number);
      current.lineHits[lineNumber] =
          (current.lineHits[lineNumber] ?? 0) + int.parse(hits);
      continue;
    }
    if (line == 'end_of_record') {
      current = null;
    }
  }
  return result;
}

/// Runs [executable] with [arguments] in [root], forwarding its output to
/// the terminal.
///
/// Throws a [CoverageException] when the process cannot be started or exits
/// with a non-zero code, since then no coverage was collected.
Future<void> _runTests(
  String executable,
  List<String> arguments,
  String root,
) async {
  final Process process;
  try {
    process = await Process.start(
      executable,
      arguments,
      workingDirectory: root,
      mode: ProcessStartMode.inheritStdio,
    );
  } on ProcessException catch (error) {
    throw CoverageException('Could not start "$executable": ${error.message}');
  }
  final int exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw CoverageException(
      '"$executable ${arguments.join(' ')}" failed with exit code $exitCode; '
      'see its output above.',
    );
  }
}

/// The comment with which `package:coverage` drops a whole file.
final _ignoreFile = RegExp(
  r'^\s*//\s*coverage:ignore-file\s*$',
  multiLine: true,
);

/// Whether [file] can show up in coverage at all: a part is reported as
/// its library, a library of nothing but directives has no lines, and a file
/// marked `// coverage:ignore-file` is left out on purpose.
bool _hasOwnCode(File file) {
  final String content = file.readAsStringSync();
  if (_ignoreFile.hasMatch(content)) {
    return false;
  }
  final CompilationUnit unit = parseString(
    content: content,
    throwIfDiagnostics: false,
  ).unit;
  final bool isPart = unit.directives.any(
    (directive) => directive is PartOfDirective,
  );
  return !isPart && unit.declarations.isNotEmpty;
}
