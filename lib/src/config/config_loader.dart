import 'dart:io';

import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:path/path.dart' as p;

/// Reads the configuration of the package in [packageRoot] from disk.
InspectraConfig loadConfig(String packageRoot) {
  final pubspec = File(p.join(packageRoot, 'pubspec.yaml'));
  if (!pubspec.existsSync()) {
    throw FileSystemException(
      'No pubspec.yaml found; run Inspectra from a package root.',
      pubspec.path,
    );
  }
  final configFile = File(p.join(packageRoot, configFileName));
  return InspectraConfig.fromSources(
    pubspec: pubspec.readAsStringSync(),
    configFile: configFile.existsSync() ? configFile.readAsStringSync() : null,
  );
}
