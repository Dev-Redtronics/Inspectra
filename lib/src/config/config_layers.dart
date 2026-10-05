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

import 'package:inspectra/src/config/config_base_cache.dart';
import 'package:inspectra/src/config/config_base_reference.dart';
import 'package:inspectra/src/config/config_layer.dart';
import 'package:inspectra/src/config/config_layer_kind.dart';
import 'package:inspectra/src/config/config_layer_stack.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/pub/package_config.dart';
import 'package:inspectra/src/pub/package_location.dart';
import 'package:inspectra/src/util/files.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The deepest chain of bases a configuration may build on.
const maxConfigDepth = 8;

/// The most layers a configuration may consist of.
const maxConfigLayers = 32;

/// Parses the YAML [text] of the configuration file [source], which is
/// read from [sourceUrl] when known.
///
/// [source] only names the file in messages and may be a label such as
/// `package:acme/inspectra.yaml`, which is no valid Windows path.
///
/// Returns the document.
///
/// Throws an [InspectraConfigException] naming the line and column of a
/// syntax error.
Object? loadConfigYaml(String text, String source, {Uri? sourceUrl}) {
  try {
    return loadYaml(
      text,
      sourceUrl: sourceUrl ?? Uri.file(source, windows: false),
    );
  } on YamlException catch (error) {
    final int? line = error.span?.start.line;
    final int? column = error.span?.start.column;
    final location = line == null || column == null
        ? ''
        : 'line ${line + 1}, column ${column + 1}: ';
    throw InspectraConfigException(source, '$location${error.message}');
  }
}

/// Builds the layer of the project's own configuration: the
/// [configFile] text when there is one, labelled [configFileLabel], or
/// else the `inspectra:` section of the parsed [pubspecYaml]; relative
/// bases resolve against [directory].
///
/// Returns the layer.
///
/// Throws an [InspectraConfigException] when [configFile] is malformed.
ConfigLayer projectConfigLayer({
  required Object? pubspecYaml,
  String? configFile,
  String configFileLabel = 'inspectra.yaml',
  String? directory,
}) {
  if (configFile != null) {
    return ConfigLayer(
      label: configFileLabel,
      kind: ConfigLayerKind.project,
      node: loadConfigYaml(configFile, configFileLabel),
      directory: directory,
      location: configFileLabel,
    );
  }
  final Object? section = pubspecYaml is Map ? pubspecYaml['inspectra'] : null;
  return ConfigLayer(
    label: 'pubspec.yaml',
    kind: ConfigLayerKind.project,
    node: section,
    yamlPath: section == null ? '' : 'inspectra',
    directory: directory,
    location: 'pubspec.yaml',
  );
}

/// Resolves the bases that [project] extends, and theirs, below the
/// package in [packageRoot]; remote bases are read from the cache in
/// [cacheRoot] only.
///
/// Returns the layers from the lowest to the highest precedence, with the
/// remote bases that are not cached yet.
///
/// Throws an [InspectraConfigException] for malformed or missing bases, a
/// cycle, or more than [maxConfigDepth] levels or [maxConfigLayers] layers.
ConfigLayerStack resolveConfigLayers(
  ConfigLayer project, {
  required String packageRoot,
  String? cacheRoot,
}) {
  final layers = <ConfigLayer>[];
  final starts = <int>[];
  final missing = <RemoteBaseReference>[];
  Map<String, PackageLocation>? packages;

  Map<String, PackageLocation> packageLocations(String label, String? file) {
    final known = packages;
    if (known != null) {
      return known;
    }
    final File? config = findUpwards(
      packageRoot,
      p.join('.dart_tool', 'package_config.json'),
    );
    if (config == null) {
      throw InspectraConfigException(
        'extends',
        '$label needs .dart_tool/package_config.json; run "dart pub get".',
        file: file,
      );
    }
    try {
      return packages = readPackageConfig(config);
    } on FormatException catch (error) {
      throw InspectraConfigException(
        'extends',
        '${config.path} is malformed: ${error.message}',
        file: file,
      );
    }
  }

  ConfigLayer readBase(
    String path,
    String label,
    ConfigLayerKind kind,
    String? declaring,
  ) {
    final file = File(path);
    if (!file.existsSync()) {
      throw InspectraConfigException(
        'extends',
        'the base $label does not exist ($path).',
        file: declaring,
      );
    }
    return ConfigLayer(
      label: label,
      kind: kind,
      node: loadConfigYaml(
        file.readAsStringSync(),
        label,
        sourceUrl: Uri.file(path),
      ),
      directory: p.dirname(path),
      location: path,
    );
  }

  (String, ConfigLayer)? load(ConfigBaseReference reference, ConfigLayer from) {
    final String? declaring = from.isBase ? from.label : null;
    switch (reference) {
      case PathBaseReference(:final String path):
        final String? directory = from.directory;
        if (directory == null) {
          throw InspectraConfigException(
            'extends',
            'a remote base cannot extend the relative path $path.',
            file: declaring,
          );
        }
        final String absolute = p.normalize(p.join(directory, path));
        final String label = posixRelative(absolute, from: packageRoot);
        return (
          absolute,
          readBase(absolute, label, ConfigLayerKind.file, declaring),
        );
      case PackageBaseReference(:final String package, :final String path):
        final PackageLocation? location = packageLocations(
          reference.label,
          declaring,
        )[package];
        if (location == null) {
          throw InspectraConfigException(
            'extends',
            'the package $package of ${reference.label} is not a dependency '
                'of the project; add it and run "dart pub get".',
            file: declaring,
          );
        }
        final String absolute = location.resolve(path);
        return (
          absolute,
          readBase(
            absolute,
            reference.label,
            ConfigLayerKind.package,
            declaring,
          ),
        );
      case RemoteBaseReference(:final Uri url, :final String sha256):
        final root = cacheRoot;
        final String? text = root == null
            ? null
            : ConfigBaseCache(root).read(sha256);
        if (text == null) {
          missing.add(reference);
          return null;
        }
        return (
          'sha256:$sha256',
          ConfigLayer(
            label: reference.label,
            kind: ConfigLayerKind.remote,
            node: loadConfigYaml(text, reference.label, sourceUrl: url),
          ),
        );
    }
  }

  void visit(ConfigLayer layer, List<String> chain) {
    final int start = layers.length;
    final Object? node = layer.node;
    final Object? entries = node is Map ? node['extends'] : null;
    final path = layer.yamlPath.isEmpty
        ? 'extends'
        : '${layer.yamlPath}.extends';
    for (final ConfigBaseReference reference in ConfigBaseReference.listOf(
      entries,
      path,
      file: layer.isBase ? layer.label : null,
    )) {
      final (String, ConfigLayer)? base = load(reference, layer);
      if (base == null) {
        continue;
      }
      final (String identity, ConfigLayer loaded) = base;
      if (chain.contains(identity)) {
        throw InspectraConfigException(
          path,
          'the bases form a cycle: ${reference.label} extends itself.',
          file: layer.isBase ? layer.label : null,
        );
      }
      if (chain.length > maxConfigDepth) {
        throw InspectraConfigException(
          path,
          'the bases are nested more than $maxConfigDepth levels deep.',
          file: layer.isBase ? layer.label : null,
        );
      }
      visit(loaded, <String>[...chain, identity]);
    }
    layers.add(layer);
    starts.add(start);
    if (layers.length > maxConfigLayers) {
      throw const InspectraConfigException(
        'extends',
        'the configuration has more than $maxConfigLayers layers.',
      );
    }
  }

  visit(project, <String>[project.location ?? project.label]);
  return ConfigLayerStack(layers: layers, starts: starts, missing: missing);
}
