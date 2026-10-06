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
import 'package:inspectra/src/baseline/baseline.dart';
import 'package:inspectra/src/cli/command/config_tool_command.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/config_bases.dart';
import 'package:inspectra/src/cli/shared_options.dart';
import 'package:inspectra/src/config/config_layers.dart';
import 'package:inspectra/src/config/config_loader.dart';
import 'package:inspectra/src/config/config_profiles.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/config_tools/config_validate_report.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/report/command_report.dart';

/// `inspectra config validate`: checks the configuration, every profile it
/// defines and every file it refers to, and reports all problems at once.
final class ConfigValidateCommand extends ConfigToolCommand {
  /// Creates the command.
  ConfigValidateCommand(super.context);

  /// The command name.
  @override
  String get name => 'validate';

  /// The one line description.
  @override
  String get description =>
      'Check the configuration and the files it refers to; exits with 65 on '
      'problems.';

  /// Validates the configuration of the project.
  ///
  /// Returns the report of a valid configuration.
  ///
  /// Throws an [InvalidInputException] listing every referenced file that
  /// is missing, every profile that is not valid and a baseline file that
  /// is malformed; an invalid configuration fails before, naming the
  /// offending key.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    final recorder = ConfigRecorder();
    final (InspectraConfig config, _) = recordConfig(results, recorder);
    final referenced = <(String, String)>[
      if (config.style.licenseHeader case final String header)
        ('style.license_header', header),
      for (final rules in config.style.customRules)
        ('style.custom_rules', rules),
      if (config.trivy.secret.config case final String secret)
        ('trivy.secret.config', secret),
      if (config.network.caCertificates case final String certificates)
        ('network.ca_certificates', certificates),
      if (config.changelog.enabled) ('changelog.file', config.changelog.file),
    ];
    final problems = <String>[
      for (final (key, file) in referenced)
        if (!File(session.resolve(file)).existsSync())
          '$key: the file $file does not exist.',
    ];
    final List<String> profiles = _profiles(results);
    final String? selected = SharedOptions.overrides(results)[profileOption];
    for (final profile in profiles) {
      if (profile == selected) {
        continue;
      }
      try {
        recordConfig(
          results,
          ConfigRecorder(),
          cli: <String, String>{profileOption: profile},
        );
      } on InspectraConfigException catch (error) {
        problems.add('profile $profile: $error');
      }
    }
    final String baseline = session.resolve(config.baseline.file);
    try {
      Baseline.load(baseline);
    } on InvalidInputException catch (error) {
      problems.add('baseline.file: ${error.message}');
    }
    if (problems.isNotEmpty) {
      throw InvalidInputException(
        'The configuration has ${problems.length} problem(s):\n'
        '${problems.map((problem) => '  $problem').join('\n')}',
      );
    }
    return ConfigValidateReport(
      source: recorder.source,
      files: <String>[for (final (_, file) in referenced) file],
      profiles: profiles,
    );
  }

  /// Lists the profiles that the project's configuration and its bases
  /// define, read as the command line [results] give.
  ///
  /// Returns the sorted profile names.
  ///
  /// Throws an [InspectraConfigException] for a malformed configuration.
  List<String> _profiles(ArgResults results) {
    final ConfigLayer project = loadProjectLayer(
      projectDirectory,
      environment: context.environment,
      configFile: results['config'] as String?,
    );
    return profileNames(
      resolveConfigLayers(
        project,
        packageRoot: projectDirectory,
        cacheRoot: cacheRootOf(context),
      ),
    );
  }
}
