import 'dart:io';

import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/util/dart_tool.dart';
import 'package:path/path.dart' as p;

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

/// The outcome of the formatting check.
class FormatResult {
  /// Creates the outcome for [checked] files, of which [unformatted] are not
  /// formatted.
  FormatResult({
    required this.checked,
    required List<String> unformatted,
    required this.failOnFindings,
    this.fixed = false,
  }) : unformatted = List.unmodifiable(unformatted..sort());

  /// How many files were checked.
  final int checked;

  /// The files that are not formatted, relative to the package root - or,
  /// when [fixed], the files that were formatted.
  final List<String> unformatted;

  /// Whether unformatted files fail the check.
  final bool failOnFindings;

  /// Whether the files were formatted in place instead of checked.
  final bool fixed;

  /// Whether the check failed.
  bool get failed => !fixed && failOnFindings && unformatted.isNotEmpty;

  /// A readable summary for the console or the build log.
  String render() {
    if (fixed) {
      return unformatted.isEmpty
          ? 'Format: all $checked file(s) were already formatted.'
          : 'Format: formatted ${unformatted.length} of $checked file(s).\n'
                '${unformatted.map((path) => '  $path').join('\n')}';
    }
    if (unformatted.isEmpty) {
      return 'Format: all $checked file(s) are formatted.';
    }
    final suffix = failed ? '' : ' (not failing)';
    final count = '${unformatted.length} of $checked file(s)';
    return [
      'Format: $count are not formatted$suffix.',
      for (final path in unformatted) '  $path',
      'Run "dart run inspectra format --fix" or "dart format ." to fix them.',
    ].join('\n');
  }

  /// Serializes this result for the JSON report.
  Map<String, Object?> toJson() => {
    'check': 'format',
    'failed': failed,
    'fixed': fixed,
    'checked': checked,
    'unformatted': unformatted,
  };
}

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

    // 0: nothing to change; 1: --set-exit-if-changed found changes.
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
