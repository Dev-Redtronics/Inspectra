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
import 'package:inspectra/src/config/config_layer.dart';
import 'package:inspectra/src/config/config_layer_kind.dart';

/// The layers of a configuration, from the lowest to the highest
/// precedence: the bases, the project's own configuration and the layers of
/// a selected profile.
///
/// A base is followed by the bases that extend it, so the layers from
/// [starts] at an index up to that index are exactly the layer and its own
/// bases, which a policy of that layer is checked against.
final class ConfigLayerStack {
  /// Creates the stack of [layers] with the [starts] of their own bases
  /// and the remote bases that are [missing] from the cache.
  const ConfigLayerStack({
    required this.layers,
    required this.starts,
    this.missing = const <RemoteBaseReference>[],
  });

  /// Every layer, from the lowest to the highest precedence.
  final List<ConfigLayer> layers;

  /// For each layer, the index of the lowest layer among its own bases, or
  /// its own index when it extends nothing.
  final List<int> starts;

  /// The remote bases that are not in the cache yet; their own bases are
  /// unknown until they are downloaded.
  final List<RemoteBaseReference> missing;

  /// The project's own configuration.
  ConfigLayer get project =>
      layers.lastWhere((layer) => layer.kind == ConfigLayerKind.project);

  /// The bases, without the project's own configuration and profiles.
  List<ConfigLayer> get bases => <ConfigLayer>[
    for (final ConfigLayer layer in layers)
      if (layer.kind != ConfigLayerKind.project &&
          layer.kind != ConfigLayerKind.profile)
        layer,
  ];

  /// Returns the layer at [index] with its own bases below it.
  List<ConfigLayer> stackOf(int index) =>
      layers.sublist(starts[index], index + 1);
}
