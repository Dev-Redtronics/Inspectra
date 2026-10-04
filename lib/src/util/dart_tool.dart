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

import 'package:inspectra/src/util/dart_tool_exception.dart';
import 'package:path/path.dart' as p;

export 'package:inspectra/src/util/dart_tool_exception.dart';

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
