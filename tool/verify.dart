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

/// The steps of `dart run tool/verify.dart`, in order: a label and the
/// `dart` arguments that run it.
const steps = <(String, List<String>)>[
  ('Format', <String>['format', '--output=none', '--set-exit-if-changed', '.']),
  ('Analyze', <String>['analyze', '--fatal-infos']),
  ('Style', <String>['run', 'bin/inspectra.dart', 'style']),
  ('Test', <String>['test']),
];

/// Runs every verification step of the repository and stops at the first
/// failure, exiting with that step's exit code.
///
/// This is the single command to run before every push; CI runs exactly the
/// same.
Future<void> main() async {
  final String dart = Platform.resolvedExecutable;
  for (final (label, arguments) in steps) {
    stdout.writeln('==> $label: dart ${arguments.join(' ')}');
    final Process process = await Process.start(
      dart,
      arguments,
      mode: ProcessStartMode.inheritStdio,
    );
    final int code = await process.exitCode;
    if (code != 0) {
      stderr.writeln('==> $label failed with exit code $code.');
      exitCode = code;
      return;
    }
  }
  stdout.writeln('==> All checks passed.');
}
