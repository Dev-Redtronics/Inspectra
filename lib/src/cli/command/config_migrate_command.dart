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

import 'package:args/command_runner.dart';
import 'package:inspectra/src/cli/command_context.dart';
import 'package:inspectra/src/cli/exit_code.dart';
import 'package:inspectra/src/config/config_loader.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/config_tools/config_migration.dart';
import 'package:inspectra/src/config_tools/config_migrator.dart';
import 'package:path/path.dart' as p;

/// `inspectra config migrate`: replaces the old names of renamed options
/// in the project's configuration file and its profiles. It reads only
/// that file, so it also works while the configuration is otherwise
/// broken. Bases are migrated by their owners.
final class ConfigMigrateCommand extends Command<int> {
  /// Creates the command with its `--config`, `--dry-run` and `--format`
  /// options.
  ConfigMigrateCommand(this.context) {
    argParser
      ..addOption(
        'config',
        help: 'Configuration file (default: $configFileName if present).',
        valueHelp: 'path',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Show what would change without writing the file.',
      )
      ..addOption(
        'format',
        abbr: 'f',
        help: 'Output format.',
        allowed: <String>['text', 'json'],
        defaultsTo: 'text',
      );
  }

  /// The outside world.
  final CommandContext context;

  /// The command name.
  @override
  String get name => 'migrate';

  /// The one line description.
  @override
  String get description =>
      'Replace the old names of renamed options in the configuration file.';

  /// Prints the usage to standard output of the [context].
  @override
  void printUsage() => context.out.writeln(usage);

  /// Migrates the configuration file.
  ///
  /// Returns `0` when the file was migrated or needs nothing; `65` for a
  /// malformed file or an option written under both names; `69` when the
  /// file cannot be written.
  @override
  Future<int> run() async {
    final directory = globalResults?['directory'] as String?;
    final String root = p.normalize(
      p.join(context.workingDirectory, directory ?? '.'),
    );
    final (File? file, List<String> keys) = _configFile(root);
    if (file == null) {
      _write(null, null, const <DeprecatedOption>[]);
      return ExitCode.success.code;
    }
    final ConfigMigration migration;
    try {
      migration = migrateConfig(
        file.readAsStringSync(),
        label: p.basename(file.path),
        root: keys,
      );
    } on InspectraConfigException catch (error) {
      context.err.writeln('error: $error');
      return ExitCode.dataError.code;
    }
    final dryRun = argResults?['dry-run'] == true;
    if (migration.changed && !dryRun) {
      try {
        File('${file.path}.tmp')
          ..writeAsStringSync(migration.content)
          ..renameSync(file.path);
      } on FileSystemException catch (error) {
        context.err.writeln(
          'error: Cannot write ${file.path}: ${error.message}',
        );
        return ExitCode.unavailable.code;
      }
    }
    _write(file.path, dryRun, migration.renamed);
    return ExitCode.success.code;
  }

  /// Finds the configuration file of the package in [root]: the one named
  /// by `--config` or `INSPECTRA_CONFIG`, `inspectra.yaml`, or
  /// `pubspec.yaml` with an `inspectra:` section.
  ///
  /// Returns the file and the keys its configuration lives at, or `null`
  /// without one.
  (File?, List<String>) _configFile(String root) {
    final String? named =
        argResults?['config'] as String? ??
        context.environment[configEnvironmentVariable];
    final file = File(p.join(root, named ?? configFileName));
    if (named != null || file.existsSync()) {
      return (file, const <String>[]);
    }
    final pubspec = File(p.join(root, 'pubspec.yaml'));
    final bool hasSection =
        pubspec.existsSync() &&
        RegExp(
          '^$pubspecSectionKey:',
          multiLine: true,
        ).hasMatch(pubspec.readAsStringSync());
    return hasSection
        ? (pubspec, const <String>[pubspecSectionKey])
        : (null, const <String>[]);
  }

  /// Reports the [renamed] options of the file at [path], which was not
  /// written in a [dryRun].
  void _write(String? path, bool? dryRun, List<DeprecatedOption> renamed) {
    if (argResults?['format'] == 'json') {
      context.out.writeln(
        const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'command': 'config migrate',
          'file': path,
          'dryRun': dryRun ?? false,
          'renamed': <Map<String, Object?>>[
            for (final option in renamed)
              <String, Object?>{
                'from': option.path,
                'to': option.deprecation.newPath,
                'line': option.line,
              },
          ],
        }),
      );
      return;
    }
    if (path == null) {
      context.out.writeln('No configuration file; nothing to migrate.');
      return;
    }
    final verb = dryRun == true ? 'Would rename' : 'Renamed';
    for (final option in renamed) {
      context.out.writeln(
        '$verb ${option.path} to ${option.deprecation.newKey} '
        '(${p.basename(path)}:${option.line}).',
      );
    }
    context.out.writeln(
      renamed.isEmpty
          ? '${p.basename(path)} uses no old option names.'
          : '${renamed.length} option(s) in ${p.basename(path)}.',
    );
  }
}
