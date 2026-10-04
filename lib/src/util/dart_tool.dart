import 'dart:io';

import 'package:path/path.dart' as p;

/// Thrown when the `dart` tool cannot be started or fails, as opposed to
/// reporting findings.
class DartToolException implements Exception {
  /// Creates the exception.
  const DartToolException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => message;
}

/// The `dart` executable: the one running Inspectra under `dart run`, or the
/// one on the `PATH` when Inspectra was compiled to an executable.
String dartExecutable() {
  final String running = Platform.resolvedExecutable;
  return p.basenameWithoutExtension(running) == 'dart' ? running : 'dart';
}

/// Runs `dart` with [arguments] in [workingDirectory] and returns the result.
///
/// Exit codes are left to the caller, which knows which ones mean findings;
/// only a `dart` that cannot be started throws a [DartToolException].
Future<ProcessResult> runDart(
  List<String> arguments, {
  required String workingDirectory,
}) async {
  final String executable = dartExecutable();
  try {
    return await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
  } on ProcessException catch (error) {
    throw DartToolException('Could not start "$executable": ${error.message}');
  }
}
