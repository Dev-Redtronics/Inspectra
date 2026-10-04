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

import 'package:path/path.dart' as p;

import 'src/style_checker.dart';

/// The directories whose Dart files are checked.
const List<String> checkedDirectories = <String>['bin', 'lib', 'test', 'tool'];

/// Checks every Dart file of the repository against the code rules of
/// `AGENTS.md` and exits with `1` when any rule is broken.
///
/// Run it from the repository root: `dart run tool/style_check.dart`.
void main() {
  const checker = StyleChecker();
  final files = <String>[
    for (final directory in checkedDirectories)
      if (Directory(directory).existsSync())
        ...Directory(directory)
            .listSync(recursive: true)
            .whereType<File>()
            .map((file) => file.path)
            .where((path) => path.endsWith('.dart'))
            .where((path) => !p.split(path).contains('fixtures')),
  ]..sort();
  final violations = files.expand(checker.checkFile).toList();
  for (final violation in violations) {
    stderr.writeln(violation);
  }
  if (violations.isNotEmpty) {
    stderr.writeln(
      '\n${violations.length} style violation(s) in '
      '${files.length} files.',
    );
    exitCode = 1;
    return;
  }
  stdout.writeln('Style check passed for ${files.length} files.');
}
