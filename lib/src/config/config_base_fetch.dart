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
import 'package:inspectra/src/config/config_fetch_outcome.dart';
import 'package:inspectra/src/config/config_layer.dart';
import 'package:inspectra/src/config/config_layer_stack.dart';
import 'package:inspectra/src/config/config_layers.dart';
import 'package:inspectra/src/config/config_overrides.dart';
import 'package:inspectra/src/config/network_config.dart';
import 'package:inspectra/src/config/yaml_reader.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/net/http_result.dart';
import 'package:inspectra/src/net/http_transport.dart';
import 'package:path/path.dart' as p;

/// The largest remote base that is downloaded.
const int maxRemoteBaseBytes = 1024 * 1024;

/// Returns the network settings for downloading the bases of [project]:
/// its own `network:` section with [overrides] on top, and the CA bundle
/// resolved against [packageRoot]. Settings in bases cannot apply, because
/// the bases are not known yet.
NetworkConfig fetchNetworkConfig(
  ConfigLayer project,
  ConfigOverrides overrides,
  String packageRoot,
) => NetworkConfig.fromYaml(
  YamlReader.layered(<ConfigLayer>[
    project,
  ], overrides: overrides).section('network'),
).withResolvedPaths((path) => p.normalize(p.join(packageRoot, path)));

/// Downloads the remote bases that [project] and its bases extend and that
/// are not in the cache in [cacheRoot] yet, through [transport], verifies
/// each against its SHA-256 and caches it.
///
/// Returns the complete layers and the bases that were downloaded.
///
/// Throws an [InvalidInputException] when a download does not match its
/// pin, an [UnavailableException] when a base cannot be downloaded or
/// cached, for example offline, and an `InspectraConfigException` for a
/// malformed configuration.
Future<ConfigFetchOutcome> fetchConfigBases(
  ConfigLayer project, {
  required String packageRoot,
  required String cacheRoot,
  required HttpTransport transport,
}) async {
  final cache = ConfigBaseCache(cacheRoot);
  final downloaded = <RemoteBaseReference>[];
  while (true) {
    final ConfigLayerStack stack = resolveConfigLayers(
      project,
      packageRoot: packageRoot,
      cacheRoot: cacheRoot,
    );
    if (stack.missing.isEmpty) {
      return ConfigFetchOutcome(stack: stack, downloaded: downloaded);
    }
    for (final RemoteBaseReference base in stack.missing) {
      if (downloaded.any((done) => done.sha256 == base.sha256)) {
        throw UnavailableException(
          'The base ${base.label} was downloaded but cannot be read from '
          'the cache in $cacheRoot.',
        );
      }
      final HttpResult result = await transport.get(
        base.url,
        maxBytes: maxRemoteBaseBytes,
      );
      if (!result.isSuccess) {
        throw UnavailableException(
          'Downloading the base ${base.label} failed with HTTP '
          '${result.statusCode}.',
        );
      }
      final String digest = ConfigBaseCache.digestOf(result.bodyBytes);
      if (digest != base.sha256) {
        throw InvalidInputException(
          'The base ${base.label} has the SHA-256 $digest, but extends pins '
          '${base.sha256}; it was not used.',
        );
      }
      try {
        cache.write(base.sha256, result.bodyBytes);
      } on FileSystemException catch (error) {
        throw UnavailableException(
          'The base ${base.label} cannot be cached in $cacheRoot: '
          '${error.message}',
        );
      }
      downloaded.add(base);
    }
  }
}
