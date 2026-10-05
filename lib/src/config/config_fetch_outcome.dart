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

import 'package:inspectra/src/config/config_base_reference.dart';
import 'package:inspectra/src/config/config_layer_stack.dart';

/// The outcome of fetching the remote bases of a configuration.
final class ConfigFetchOutcome {
  /// Creates the outcome with the resolved [stack] and the remote bases
  /// that were [downloaded] now rather than taken from the cache.
  const ConfigFetchOutcome({
    required this.stack,
    this.downloaded = const <RemoteBaseReference>[],
  });

  /// Every layer of the configuration, with all remote bases cached.
  final ConfigLayerStack stack;

  /// The remote bases that were downloaded.
  final List<RemoteBaseReference> downloaded;
}
