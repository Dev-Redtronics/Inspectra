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

import 'package:inspectra/src/config/config_layers.dart';
import 'package:inspectra/src/config/config_overrides.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/host/cache_directory.dart';
import 'package:inspectra/src/host/host_platform.dart';
import 'package:inspectra/src/io/environment.dart';
import 'package:path/path.dart' as p;

/// The environment variable naming an alternative configuration file.
const configEnvironmentVariable = 'INSPECTRA_CONFIG';

/// Reads the configuration of the package in [packageRoot] from disk.
///
/// The configuration file is, in order: [configFile] (the `--config` flag),
/// the file named by `INSPECTRA_CONFIG`, `inspectra.yaml` in [packageRoot],
/// and finally the `inspectra:` section of `pubspec.yaml`. [overrides]
/// layers environment variables and command line values on top, and a
/// [recorder] records every value with its origin.
///
/// The bases named by `extends` are resolved relative to the configuration
/// file; remote bases are read from the cache in [cacheRoot], by default
/// the Inspectra cache directory of the environment.
///
/// With [requirePubspec], a missing `pubspec.yaml` is an error; the
/// supply-chain commands pass `false` because they also work outside of a
/// package, for example `inspectra trust http`.
///
/// Returns the configuration.
///
/// Throws a [FileSystemException] when a required `pubspec.yaml` is missing
/// and an [InspectraConfigException] when a named configuration file does
/// not exist or any file is invalid.
InspectraConfig loadConfig(
  String packageRoot, {
  ConfigOverrides? overrides,
  String? configFile,
  bool requirePubspec = true,
  ConfigRecorder? recorder,
  String? cacheRoot,
}) {
  final pubspec = File(p.join(packageRoot, 'pubspec.yaml'));
  final bool hasPubspec = pubspec.existsSync();
  if (requirePubspec && !hasPubspec) {
    throw FileSystemException(
      'No pubspec.yaml found; run Inspectra from a package root.',
      pubspec.path,
    );
  }
  final String? named =
      configFile ?? overrides?.environment[configEnvironmentVariable];
  final config = File(p.join(packageRoot, named ?? configFileName));
  final bool hasConfig = config.existsSync();
  if (named != null && !hasConfig) {
    throw InspectraConfigException(
      named,
      'the configuration file does not exist.',
    );
  }
  return InspectraConfig.fromSources(
    pubspec: hasPubspec ? pubspec.readAsStringSync() : null,
    configFile: hasConfig ? config.readAsStringSync() : null,
    configFileLabel: p.basename(config.path),
    overrides: overrides,
    recorder: recorder,
    packageRoot: packageRoot,
    cacheRoot:
        cacheRoot ??
        defaultCacheRoot(overrides?.environment ?? Environment.current()),
    configDirectory: p.dirname(config.absolute.path),
  );
}

/// Reads the project's own configuration of the package in [packageRoot],
/// chosen as [loadConfig] chooses it, without resolving its bases.
///
/// Returns the layer.
///
/// Throws an [InspectraConfigException] when a named configuration file
/// does not exist or a file is malformed.
ConfigLayer loadProjectLayer(
  String packageRoot, {
  Environment? environment,
  String? configFile,
}) {
  final pubspec = File(p.join(packageRoot, 'pubspec.yaml'));
  final String? named = configFile ?? environment?[configEnvironmentVariable];
  final config = File(p.join(packageRoot, named ?? configFileName));
  final bool hasConfig = config.existsSync();
  if (named != null && !hasConfig) {
    throw InspectraConfigException(
      named,
      'the configuration file does not exist.',
    );
  }
  return projectConfigLayer(
    pubspecYaml: pubspec.existsSync()
        ? loadConfigYaml(pubspec.readAsStringSync(), 'pubspec.yaml')
        : null,
    configFile: hasConfig ? config.readAsStringSync() : null,
    configFileLabel: p.basename(config.path),
    directory: p.dirname(config.absolute.path),
  );
}

/// Returns the Inspectra cache directory of [environment], where remote
/// bases of configurations are kept.
String defaultCacheRoot(Environment environment) => CacheDirectory(
  environment: environment,
  host: HostPlatform.current(),
).resolveOrTemp();
