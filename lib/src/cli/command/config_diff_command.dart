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

import 'package:args/args.dart';
import 'package:inspectra/src/changelog/git_history.dart';
import 'package:inspectra/src/cli/command/config_tool_command.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/config_bases.dart';
import 'package:inspectra/src/cli/shared_options.dart';
import 'package:inspectra/src/config/config_loader.dart';
import 'package:inspectra/src/config/config_overrides.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/config_tools/config_diff_report.dart';
import 'package:inspectra/src/config_tools/config_differ.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:path/path.dart' as p;

/// `inspectra config diff <a> [<b>]`: compares two configurations option
/// by option, each a file or `git:<revision>`, the second the effective
/// configuration by default.
final class ConfigDiffCommand extends ConfigToolCommand {
  /// Creates the command with its `--fail-on-weaker` flag.
  ConfigDiffCommand(super.context) {
    argParser.addFlag(
      'fail-on-weaker',
      negatable: false,
      help: 'Exit with 1 when an option of the second configuration is weaker.',
    );
  }

  /// The prefix of a configuration read from a Git revision.
  static const _gitPrefix = 'git:';

  /// The command name.
  @override
  String get name => 'diff';

  /// The one line description.
  @override
  String get description =>
      'Compare two configurations, files or git:<revision>, option by '
      'option.';

  /// The usage line.
  @override
  String get invocation =>
      'inspectra config diff <file|git:revision> [<file|git:revision>]';

  /// Compares the configurations named on the command line.
  ///
  /// Returns the report.
  ///
  /// Throws an [InvalidUsageException] for a wrong number of arguments or
  /// an unknown revision, an [InvalidInputException] for a missing file
  /// and an `InspectraConfigException` for an invalid configuration.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    final List<String> sides = results.rest;
    if (sides.isEmpty || sides.length > 2) {
      throw InvalidUsageException(
        'config diff takes one or two configurations, files or '
        'git:<revision>; got ${sides.length}.',
      );
    }
    final ConfigRecorder from = await _record(sides.first, results);
    final ConfigRecorder to = sides.length == 2
        ? await _record(sides.last, results)
        : _effective(results);
    return ConfigDiffReport(
      from: sides.first,
      to: sides.length == 2 ? sides.last : 'the effective configuration',
      changes: diffConfigs(from, to),
      failOnWeaker: results['fail-on-weaker'] == true,
    );
  }

  /// Reads the effective configuration as the command line [results] give.
  ///
  /// Returns what reading it recorded.
  ///
  /// Throws an `InspectraConfigException` for an invalid configuration.
  ConfigRecorder _effective(ArgResults results) {
    final recorder = ConfigRecorder();
    recordConfig(results, recorder);
    return recorder;
  }

  /// Reads the configuration [side] - a file, or `git:<revision>` for the
  /// project's configuration at that revision - with the overrides of the
  /// command line [results].
  ///
  /// Returns what reading it recorded.
  ///
  /// Throws an [InvalidInputException] for a missing file, an
  /// [InvalidUsageException] for an unknown revision and an
  /// `InspectraConfigException` for an invalid configuration.
  Future<ConfigRecorder> _record(String side, ArgResults results) async {
    final (
      String? pubspec,
      String? config,
      String label,
    ) = side.startsWith(_gitPrefix)
        ? await _atRevision(side.substring(_gitPrefix.length), results)
        : _fromFile(side);
    final recorder = ConfigRecorder();
    InspectraConfig.fromSources(
      pubspec: pubspec,
      configFile: config,
      configFileLabel: label,
      overrides: ConfigOverrides(
        cli: SharedOptions.overrides(results),
        environment: context.environment,
      ),
      recorder: recorder,
      packageRoot: projectDirectory,
      cacheRoot: cacheRootOf(context),
    );
    return recorder;
  }

  /// Reads the project's `pubspec.yaml` and configuration file at
  /// [revision], the file named as the command line [results] give.
  ///
  /// Returns the pubspec (the current one when the revision has none), the
  /// configuration file or `null`, and a label.
  ///
  /// Throws an [InvalidUsageException] for an unknown revision.
  Future<(String?, String?, String)> _atRevision(
    String revision,
    ArgResults results,
  ) async {
    final history = GitHistory(
      processRunner: context.processRunner,
      workingDirectory: projectDirectory,
    );
    final String name = _configName(results);
    final String? config = await history.show(revision, name);
    final String? pubspec =
        await history.show(revision, 'pubspec.yaml') ?? _pubspec();
    return (pubspec, config, '$name at $revision');
  }

  /// Reads the configuration file [side]; a `pubspec.yaml` is read as the
  /// pubspec with its section.
  ///
  /// Returns the pubspec, the configuration file or `null`, and a label.
  ///
  /// Throws an [InvalidInputException] when the file does not exist.
  (String?, String?, String) _fromFile(String side) {
    final file = File(p.join(projectDirectory, side));
    if (!file.existsSync()) {
      throw InvalidInputException('$side does not exist.');
    }
    final String content = file.readAsStringSync();
    if (p.basename(side) == 'pubspec.yaml') {
      return (content, null, side);
    }
    return (_pubspec(), content, side);
  }

  /// Returns the name of the project's configuration file: the one named
  /// by `--config` or `INSPECTRA_CONFIG`, else `inspectra.yaml`.
  String _configName(ArgResults results) =>
      results['config'] as String? ??
      context.environment[configEnvironmentVariable] ??
      configFileName;

  /// Returns the current `pubspec.yaml` of the project, or `null` without
  /// one.
  String? _pubspec() {
    final file = File(p.join(projectDirectory, 'pubspec.yaml'));
    return file.existsSync() ? file.readAsStringSync() : null;
  }
}
