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
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/config_tools/config_preset.dart';
import 'package:inspectra/src/config_tools/config_presets.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/pub/pubspec_parser.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// `inspectra config init`: writes a starting `inspectra.yaml` for the kind
/// of package in the directory. It reads no project configuration, so it
/// also works while that configuration is broken.
final class ConfigInitCommand extends Command<int> {
  /// Creates the command with its `--preset`, `--stdout` and `--force`
  /// options.
  ConfigInitCommand(this.context) {
    argParser
      ..addOption(
        'preset',
        help:
            'The kind of package (default: detected from pubspec.yaml - '
            'plugin, library when published, app otherwise).',
        allowed: <String>[for (final preset in ConfigPreset.values) preset.id],
      )
      ..addFlag(
        'stdout',
        negatable: false,
        help: 'Print the configuration instead of writing $configFileName.',
      )
      ..addFlag(
        'force',
        negatable: false,
        help: 'Replace an existing $configFileName.',
      );
  }

  /// The outside world.
  final CommandContext context;

  /// The command name.
  @override
  String get name => 'init';

  /// The one line description.
  @override
  String get description =>
      'Write a starting $configFileName for an app, library, plugin or '
      'enterprise project.';

  /// Prints the usage to standard output of the [context].
  @override
  void printUsage() => context.out.writeln(usage);

  /// Writes the configuration, or prints it with `--stdout`.
  ///
  /// Returns `0`; `64` when the file exists without `--force`; `65` for a
  /// malformed `pubspec.yaml`; `69` when the file cannot be written.
  @override
  Future<int> run() async {
    final directory = globalResults?['directory'] as String?;
    final String root = p.normalize(
      p.join(context.workingDirectory, directory ?? '.'),
    );
    final Pubspec? pubspec;
    final bool plugin;
    final bool section;
    try {
      (pubspec, plugin, section) = _readPubspec(root);
    } on InvalidInputException catch (error) {
      context.err.writeln('error: ${error.message}');
      return ExitCode.dataError.code;
    }
    final presetId = argResults?['preset'] as String?;
    final bool publishable = pubspec?.isPublishable ?? false;
    final ConfigPreset preset = presetId == null
        ? detectPreset(plugin: plugin, publishable: publishable)
        : ConfigPreset.values.firstWhere((value) => value.id == presetId);
    final String text = renderPreset(
      preset,
      flutter: pubspec?.isFlutterProject ?? false,
      publishable: publishable,
    );
    if (argResults?['stdout'] == true) {
      context.out.write(text);
      return ExitCode.success.code;
    }
    final file = File(p.join(root, configFileName));
    final force = argResults?['force'] == true;
    if (file.existsSync() && !force) {
      context.err.writeln(
        'error: ${file.path} exists; use --force to replace it, or --stdout '
        'to print the configuration.',
      );
      return ExitCode.usage.code;
    }
    try {
      file.writeAsStringSync(text);
    } on FileSystemException catch (error) {
      context.err.writeln('error: Cannot write ${file.path}: ${error.message}');
      return ExitCode.unavailable.code;
    }
    context.err.writeln('Wrote ${file.path} with the ${preset.id} preset.');
    if (section) {
      context.err.writeln(
        'warning: pubspec.yaml has an $pubspecSectionKey: section, which '
        '$configFileName now replaces; move its settings over and remove it.',
      );
    }
    return ExitCode.success.code;
  }

  /// Reads `pubspec.yaml` in [root].
  ///
  /// Returns the pubspec, or `null` without one; whether it declares a
  /// Flutter plugin; and whether it has an `inspectra:` section.
  ///
  /// Throws an [InvalidInputException] for a malformed pubspec.
  (Pubspec?, bool, bool) _readPubspec(String root) {
    final file = File(p.join(root, 'pubspec.yaml'));
    if (!file.existsSync()) {
      return (null, false, false);
    }
    final String content = file.readAsStringSync();
    final Pubspec pubspec = const PubspecParser().parse(
      content,
      path: file.path,
    );
    final Object? yaml = loadYaml(content);
    final Object? flutter = yaml is Map ? yaml['flutter'] : null;
    final bool plugin = flutter is Map && flutter['plugin'] != null;
    final bool section = yaml is Map && yaml.containsKey(pubspecSectionKey);
    return (pubspec, plugin, section);
  }
}
