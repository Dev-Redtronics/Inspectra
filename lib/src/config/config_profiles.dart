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

import 'package:inspectra/src/config/config_layer.dart';
import 'package:inspectra/src/config/config_layer_kind.dart';
import 'package:inspectra/src/config/config_layer_stack.dart';
import 'package:inspectra/src/config/config_policy.dart';
import 'package:inspectra/src/config/config_suggestion.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';

/// The top-level key of a configuration file that holds its profiles.
const profilesKey = 'profiles';

/// The option that selects a profile: `--profile`, `--set profile=...` and
/// `INSPECTRA_PROFILE`.
const profileOption = 'profile';

/// The keys a profile cannot set, because they are resolved before the
/// profile is applied.
const _reservedInProfile = <String>['extends', 'policy', profilesKey];

/// Adds the profile [name] of every layer of [stack] on top of it, in the
/// order of the layers that define it, so that a profile wins over the
/// project's own configuration but not over `INSPECTRA_*` variables and
/// the command line.
///
/// Returns the stack with the profile layers.
///
/// Throws an [InspectraConfigException] when no layer defines the profile,
/// or a `profiles` section or the profile is malformed.
ConfigLayerStack withProfile(ConfigLayerStack stack, String name) {
  final layers = <ConfigLayer>[...stack.layers];
  final starts = <int>[...stack.starts];
  final defined = <String>{};
  for (final ConfigLayer layer in stack.layers) {
    final Map<Object?, Object?>? profiles = profilesOf(layer);
    if (profiles == null) {
      continue;
    }
    defined.addAll(<String>[for (final Object? key in profiles.keys) '$key']);
    if (!profiles.containsKey(name)) {
      continue;
    }
    final Object? profile = profiles[name];
    final path = '${ConfigPolicy.pathIn(layer, profilesKey)}.$name';
    final String? file = layer.isBase ? layer.label : null;
    if (profile != null && profile is! Map) {
      throw InspectraConfigException(path, 'expected a mapping.', file: file);
    }
    for (final String key in _reservedInProfile) {
      final bool reserved = profile is Map && profile.containsKey(key);
      if (reserved) {
        throw InspectraConfigException(
          '$path.$key',
          'a profile cannot set $key; set it outside of profiles.',
          file: file,
        );
      }
    }
    starts.add(layers.length);
    layers.add(
      ConfigLayer(
        label: 'profile $name of ${layer.label}',
        kind: ConfigLayerKind.profile,
        node: profile,
        yamlPath: path,
        directory: layer.directory,
        location: layer.location ?? layer.label,
      ),
    );
  }
  if (layers.length == stack.layers.length) {
    final List<String> known = defined.toList()..sort();
    throw InspectraConfigException(
      profileOption,
      known.isEmpty
          ? 'no configuration defines the profile "$name"; add it below '
                '$profilesKey.'
          : 'unknown profile "$name".${didYouMean(name, known)} Known '
                'profiles: ${known.join(', ')}.',
    );
  }
  return ConfigLayerStack(
    layers: layers,
    starts: starts,
    missing: stack.missing,
  );
}

/// Lists the profiles that the layers of [stack] define.
///
/// Returns the sorted profile names.
///
/// Throws an [InspectraConfigException] when a `profiles` section is no
/// mapping.
List<String> profileNames(ConfigLayerStack stack) {
  final names = <String>{
    for (final ConfigLayer layer in stack.layers)
      for (final Object? key in profilesOf(layer)?.keys ?? const <Object?>[])
        '$key',
  };
  return names.toList()..sort();
}

/// Reads the `profiles` section of [layer].
///
/// Returns the profiles by name, or `null` when the layer has none.
///
/// Throws an [InspectraConfigException] when the section is no mapping.
Map<Object?, Object?>? profilesOf(ConfigLayer layer) {
  final Object? node = layer.node;
  final Object? profiles = node is Map ? node[profilesKey] : null;
  if (profiles == null) {
    return null;
  }
  if (profiles is! Map) {
    throw InspectraConfigException(
      ConfigPolicy.pathIn(layer, profilesKey),
      'expected a mapping from profile names to configurations.',
      file: layer.isBase ? layer.label : null,
    );
  }
  return profiles;
}
