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

import 'package:build/build.dart';

import 'package:inspectra/src/config/inspectra_config.dart';

/// Whether the warning about an `inspectra.yaml` that build_runner cannot
/// see has been logged, so that it is logged once per build, not per builder.
var _warnedAboutUntrackedConfig = false;

/// Reads the configuration of the package [buildStep] builds, through the
/// build step so that a change to it reruns the builder.
///
/// `pubspec.yaml` is always visible to build_runner. `inspectra.yaml` is
/// only visible when the package lists it in its `build.yaml` sources;
/// otherwise it is read from disk, and a change to it takes effect with the
/// next build that has another reason to run - so this warns once.
Future<InspectraConfig> readConfig(BuildStep buildStep) async {
  final String package = buildStep.inputId.package;
  final String pubspec = await buildStep.readAsString(
    AssetId(package, 'pubspec.yaml'),
  );

  final String? configFile = await _readConfigFile(
    buildStep,
    AssetId(package, configFileName),
  );
  return InspectraConfig.fromSources(pubspec: pubspec, configFile: configFile);
}

/// Reads `inspectra.yaml` through [buildStep] when it is a build source
/// ([configId]), so that editing it reruns the builders, and otherwise from
/// disk, warning once that edits do not rerun Inspectra.
///
/// Returns the file content, or `null` when there is no such file.
Future<String?> _readConfigFile(BuildStep buildStep, AssetId configId) async {
  if (await buildStep.canRead(configId)) {
    return buildStep.readAsString(configId);
  }
  final file = File(configFileName);
  if (!file.existsSync()) {
    return null;
  }
  if (!_warnedAboutUntrackedConfig) {
    _warnedAboutUntrackedConfig = true;
    log.warning(
      '$configFileName is not a build_runner source, so editing it does '
      'not rerun Inspectra. Add it to the sources in build.yaml, or move '
      'the settings to an "inspectra:" section of pubspec.yaml.',
    );
  }
  return file.readAsStringSync();
}

/// Whether [id] is a file in the package directory, as opposed to an output
/// another builder keeps in the build cache - such as the test bootstraps of
/// `build_test`, which `findAssets` reports as well.
bool isInPackage(AssetId id) => File(id.path).existsSync();
