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

import 'package:inspectra/src/config_tools/config_preset.dart';
import 'package:inspectra/src/config_tools/config_schema.dart';

/// Chooses the preset for a package from its pubspec: a Flutter plugin, a
/// package published to a registry ([publishable]) or an application.
///
/// Returns the preset.
ConfigPreset detectPreset({required bool plugin, required bool publishable}) {
  if (plugin) {
    return ConfigPreset.plugin;
  }
  return publishable ? ConfigPreset.library : ConfigPreset.app;
}

/// Writes the starting `inspectra.yaml` of [preset] for a package that
/// uses Flutter when [flutter] is set and is published to a registry when
/// [publishable] is set; [publishable] only matters for
/// [ConfigPreset.enterprise].
///
/// Returns the text of the file.
String renderPreset(
  ConfigPreset preset, {
  required bool flutter,
  required bool publishable,
}) {
  final bool published = switch (preset) {
    ConfigPreset.app => false,
    ConfigPreset.library => true,
    ConfigPreset.plugin => true,
    ConfigPreset.enterprise => publishable,
  };
  final strict = preset == ConfigPreset.enterprise;
  final bool flutterRunner = flutter || preset == ConfigPreset.plugin;
  final devOnly = <String>[
    'build_runner',
    if (flutterRunner) 'flutter_lints',
    if (flutterRunner) 'flutter_test',
    'lints',
    'mockito',
    'test',
  ];
  final out = StringBuffer()
    ..writeln('# yaml-language-server: \$schema=$configSchemaUrl')
    ..writeln('#')
    ..writeln(
      '# Created by "inspectra config init --preset ${preset.id}". '
      '"inspectra config show',
    )
    ..writeln(
      '# --explain" prints every option with its value and where it '
      'comes from.',
    )
    ..writeln();
  if (strict) {
    out
      ..writeln('# Share these settings across repositories with a policy:')
      ..writeln('# extends: package:acme_policy/inspectra.yaml')
      ..writeln();
  }
  out
    ..writeln('fail_on: ${strict ? 'medium' : 'high'}')
    ..writeln()
    ..writeln('format:')
    ..writeln('  enabled: true')
    ..writeln('lint:')
    ..writeln('  enabled: true')
    ..writeln('  fail_on: ${published || strict ? 'info' : 'warning'}')
    ..writeln('style:')
    ..writeln('  enabled: true')
    ..writeln('  preset: recommended')
    ..writeln('coverage:')
    ..writeln('  enabled: true');
  if (flutterRunner) {
    out.writeln('  runner: flutter');
  }
  out
    ..writeln('  min_line_coverage: ${published ? 80 : 70}')
    ..writeln('trivy:')
    ..writeln('  enabled: true');
  if (strict) {
    out.writeln('  mode: required');
  }
  if (published) {
    out
      ..writeln('api:')
      ..writeln('  enabled: true')
      ..writeln('  semver: true')
      ..writeln('changelog:')
      ..writeln('  enabled: true');
  }
  out
    ..writeln()
    ..writeln('dependency_policy:')
    ..writeln('  enabled: true')
    ..writeln('  require_upper_bound: true')
    ..writeln('  dev_only: [${devOnly.join(', ')}]')
    ..writeln('  lockfile_in_sync: true');
  if (!published) {
    out.writeln('  require_publish_to: true');
  }
  if (published) {
    out.writeln('  required_metadata: [description, repository]');
  }
  if (strict) {
    out
      ..writeln('  lockfile_checksums: true')
      ..writeln('  check_imports: true');
  }
  out
    ..writeln()
    ..writeln('baseline:')
    ..writeln('  max_severity: ${strict ? 'medium' : 'high'}');
  if (strict) {
    out
      ..writeln()
      ..writeln('profiles:')
      ..writeln('  local:')
      ..writeln('    trivy:')
      ..writeln('      mode: auto')
      ..writeln('  ci:')
      ..writeln('    fail_on: low');
  }
  return out.toString();
}
