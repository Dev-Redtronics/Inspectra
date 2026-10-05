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

import 'package:inspectra/src/cli/command_context.dart';
import 'package:inspectra/src/config/config_base_fetch.dart';
import 'package:inspectra/src/config/config_fetch_outcome.dart';
import 'package:inspectra/src/config/config_layer.dart';
import 'package:inspectra/src/config/config_layer_stack.dart';
import 'package:inspectra/src/config/config_layers.dart';
import 'package:inspectra/src/config/config_loader.dart';
import 'package:inspectra/src/config/config_overrides.dart';
import 'package:inspectra/src/host/cache_directory.dart';
import 'package:inspectra/src/net/http_transport.dart';

/// Returns the Inspectra cache directory of [context].
String cacheRootOf(CommandContext context) => CacheDirectory(
  environment: context.environment,
  host: context.host,
).resolveOrTemp();

/// Makes the remote bases of the configuration of the package in
/// [packageRoot] available before it is loaded: the ones missing from the
/// cache are downloaded and verified. [configFile] is the `--config` flag
/// and [cli] the command line overrides, which may configure the network.
///
/// Returns the layers and what was downloaded; nothing is downloaded, and
/// no connection opened, when every base is local or cached.
///
/// Throws an `InspectraConfigException` for a malformed configuration, an
/// `InvalidInputException` for a download that does not match its pin and
/// an `UnavailableException` when a base cannot be downloaded.
Future<ConfigFetchOutcome> prepareConfigBases(
  CommandContext context,
  String packageRoot, {
  String? configFile,
  Map<String, String> cli = const <String, String>{},
}) async {
  final ConfigLayer project = loadProjectLayer(
    packageRoot,
    environment: context.environment,
    configFile: configFile,
  );
  final String cacheRoot = cacheRootOf(context);
  final ConfigLayerStack stack = resolveConfigLayers(
    project,
    packageRoot: packageRoot,
    cacheRoot: cacheRoot,
  );
  if (stack.missing.isEmpty) {
    return ConfigFetchOutcome(stack: stack);
  }
  final transport = HttpTransport(
    config: fetchNetworkConfig(
      project,
      ConfigOverrides(cli: cli, environment: context.environment),
      packageRoot,
    ),
    environment: context.environment,
    sleep: context.sleep,
  );
  try {
    return await fetchConfigBases(
      project,
      packageRoot: packageRoot,
      cacheRoot: cacheRoot,
      transport: transport,
    );
  } finally {
    transport.close();
  }
}
