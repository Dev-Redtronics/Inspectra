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

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// A stand-in for the Trivy executable that records how it was called.
class FakeTrivy {
  /// Creates a fake that writes [report] as its JSON report and exits with
  /// [exitCode].
  factory FakeTrivy(
    String directory, {
    Map<String, Object?> report = const {},
    int exitCode = 0,
  }) {
    final String reportFile = p.join(directory, 'canned.json');
    File(reportFile).writeAsStringSync(jsonEncode(report));
    final script = File(p.join(directory, 'trivy'))
      ..writeAsStringSync('''
#!/bin/sh
if [ "\$1" = "--version" ]; then echo '{"Version":"0.75.0"}'; exit 0; fi
out=""
previous=""
for argument in "\$@"; do
  if [ "\$previous" = "--output" ]; then out="\$argument"; fi
  previous="\$argument"
done
eval target=\\\${\$#}
printf '%s\\n' "\$@" > "$directory/arguments.txt"
(cd "\$target" && find . -type f | sort) > "$directory/files.txt"
if [ -f "\$target/pubspec.lock" ]; then cp "\$target/pubspec.lock" "$directory/scanned.lock"; fi
cp "$reportFile" "\$out"
exit $exitCode
''');
    Process.runSync('chmod', ['+x', script.path]);
    return FakeTrivy._(script.path, directory);
  }

  /// Creates the fake from its script [executable] and the [_directory] it
  /// records its invocations in.
  FakeTrivy._(this.executable, this._directory);

  /// The path of the fake executable.
  final String executable;

  /// The directory the fake writes its arguments, files and report into.
  final String _directory;

  /// The arguments of the last invocation.
  List<String> get arguments =>
      File(p.join(_directory, 'arguments.txt')).readAsLinesSync();

  /// The files in the scanned directory, relative to it.
  List<String> get scannedFiles =>
      File(p.join(_directory, 'files.txt'))
          .readAsLinesSync()
          .map((line) => line.substring(2))
          .toList();

  /// The `pubspec.lock` that was scanned.
  String get scannedLock =>
      File(p.join(_directory, 'scanned.lock')).readAsStringSync();
}
