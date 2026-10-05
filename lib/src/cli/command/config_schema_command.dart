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

import 'package:args/command_runner.dart';
import 'package:inspectra/src/cli/command_context.dart';
import 'package:inspectra/src/cli/exit_code.dart';
import 'package:inspectra/src/config_tools/config_schema.dart';
import 'package:path/path.dart' as p;

/// `inspectra config schema`: prints the JSON Schema of `inspectra.yaml`
/// for editors. It reads no project configuration, so it also works while
/// that configuration is broken.
final class ConfigSchemaCommand extends Command<int> {
  /// Creates the command with its `--output` option.
  ConfigSchemaCommand(this.context) {
    argParser.addOption(
      'output',
      abbr: 'o',
      valueHelp: 'path',
      help: 'Write the schema to a file instead of standard output.',
    );
  }

  /// The outside world.
  final CommandContext context;

  /// The command name.
  @override
  String get name => 'schema';

  /// The one line description.
  @override
  String get description =>
      'Print the JSON Schema of inspectra.yaml, for completion and '
      'validation in editors.';

  /// Prints the usage to standard output of the [context].
  @override
  void printUsage() => context.out.writeln(usage);

  /// Writes the schema.
  ///
  /// Returns `0`, or `69` when the output file cannot be written.
  @override
  Future<int> run() async {
    final String schema = renderConfigSchema();
    final output = argResults?['output'] as String?;
    if (output == null) {
      context.out.write(schema);
      return ExitCode.success.code;
    }
    final directory = globalResults?['directory'] as String?;
    final String path = p.normalize(
      p.join(context.workingDirectory, directory ?? '.', output),
    );
    try {
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(schema);
    } on FileSystemException catch (error) {
      context.err.writeln(
        'error: Cannot write the schema to $path: '
        '${error.message}',
      );
      return ExitCode.unavailable.code;
    }
    context.err.writeln('Schema written to $path');
    return ExitCode.success.code;
  }
}
