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

import 'package:inspectra/inspectra.dart';

import 'fake_process_runner.dart';

/// Runs the complete Inspectra command line in-process against a temporary
/// project directory, capturing standard output and error.
final class TestHarness {
  /// Creates a harness for the project in [workingDirectory].
  ///
  /// [environment] adds variables to an otherwise empty environment, so no
  /// proxy or `PATH` of the machine leaks into the test. [processRunner]
  /// replaces external tools and [now] fixes the clock.
  TestHarness({
    required this.workingDirectory,
    Map<String, String> environment = const <String, String>{},
    ProcessRunner? processRunner,
    DateTime? now,
  }) : context = CommandContext(
         environment: Environment(<String, String>{
           'INSPECTRA_CACHE_DIR': '$workingDirectory/.inspectra-cache',
           ...environment,
         }),
         clock: Clock(() => now ?? DateTime.utc(2026, 10)),
         processRunner:
             processRunner ??
             FakeProcessRunner(
               (executable, arguments) => const ProcessOutcome(
                 exitCode: 127,
                 stdout: '',
                 stderr: 'not found',
               ),
             ),
         host: HostPlatform.current(),
         workingDirectory: workingDirectory,
         out: StringBuffer(),
         err: StringBuffer(),
         sleep: (_) async {},
       );

  /// Creates a harness for a fresh temporary directory containing [files].
  ///
  /// Returns the harness; delete [workingDirectory] in `tearDown`.
  factory TestHarness.withFiles(
    Map<String, String> files, {
    Map<String, String> environment = const <String, String>{},
    ProcessRunner? processRunner,
  }) {
    final Directory directory = Directory.systemTemp.createTempSync(
      'inspectra_test_',
    );
    for (final MapEntry<String, String> entry in files.entries) {
      File('${directory.path}/${entry.key}')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(entry.value);
    }
    return TestHarness(
      workingDirectory: directory.path,
      environment: environment,
      processRunner: processRunner,
    );
  }

  /// The project directory.
  final String workingDirectory;

  /// The context passed to the command line.
  final CommandContext context;

  /// Everything written to standard output.
  String get out => '${context.out}';

  /// Everything written to standard error.
  String get err => '${context.err}';

  /// Runs the command line with [arguments].
  ///
  /// Returns the exit code.
  Future<int> run(List<String> arguments) =>
      InspectraCommandRunner(context).run(arguments);

  /// Deletes the project directory.
  void dispose() => Directory(workingDirectory).deleteSync(recursive: true);
}
