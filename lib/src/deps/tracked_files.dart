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

import 'package:inspectra/src/io/process_outcome.dart';
import 'package:inspectra/src/io/process_runner.dart';
import 'package:path/path.dart' as p;

/// Lists the files Git tracks in [directory] and below it, through
/// [runner].
///
/// Returns their absolute, normalised paths, or `null` when [directory] is
/// not inside a Git repository or Git cannot be started.
Future<Set<String>?> trackedFiles(
  ProcessRunner runner,
  String directory,
) async {
  final ProcessOutcome outcome;
  try {
    outcome = await runner.run(
      'git',
      const <String>['ls-files', '-z', '--', '.'],
      workingDirectory: directory,
      environment: const <String, String>{'LC_ALL': 'C'},
    );
  } on ProcessException {
    return null;
  }
  if (!outcome.succeeded) {
    return null;
  }
  final String root = p.absolute(directory);
  return <String>{
    for (final String path in outcome.stdout.split('\u0000'))
      if (path.isNotEmpty) p.normalize(p.join(root, path)),
  };
}
