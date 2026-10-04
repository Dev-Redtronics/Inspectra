import 'dart:io';

import 'package:inspectra/src/config/config_overrides.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:path/path.dart' as p;

/// The environment variable naming an alternative configuration file.
const String configEnvironmentVariable = 'INSPECTRA_CONFIG';

/// Reads the configuration of the package in [packageRoot] from disk.
///
/// The configuration file is, in order: [configFile] (the `--config` flag),
/// the file named by `INSPECTRA_CONFIG`, `inspectra.yaml` in [packageRoot],
/// and finally the `inspectra:` section of `pubspec.yaml`. [overrides]
/// layers environment variables and command line values on top.
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
}) {
  final pubspec = File(p.join(packageRoot, 'pubspec.yaml'));
  final hasPubspec = pubspec.existsSync();
  if (requirePubspec && !hasPubspec) {
    throw FileSystemException(
      'No pubspec.yaml found; run Inspectra from a package root.',
      pubspec.path,
    );
  }
  final named = configFile ?? overrides?.environment[configEnvironmentVariable];
  final config = File(p.join(packageRoot, named ?? configFileName));
  final hasConfig = config.existsSync();
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
  );
}
