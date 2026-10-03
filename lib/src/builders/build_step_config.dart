import 'dart:io';

import 'package:build/build.dart';

import 'package:inspectra/src/config/inspectra_config.dart';

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

  final configId = AssetId(package, configFileName);
  String? configFile;
  if (await buildStep.canRead(configId)) {
    configFile = await buildStep.readAsString(configId);
  } else {
    final file = File(configFileName);
    if (file.existsSync()) {
      configFile = file.readAsStringSync();
      if (!_warnedAboutUntrackedConfig) {
        _warnedAboutUntrackedConfig = true;
        log.warning(
          '$configFileName is not a build_runner source, so editing it does '
          'not rerun Inspectra. Add it to the sources in build.yaml, or move '
          'the settings to an "inspectra:" section of pubspec.yaml.',
        );
      }
    }
  }
  return InspectraConfig.fromSources(pubspec: pubspec, configFile: configFile);
}
