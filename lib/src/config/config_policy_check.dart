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

import 'dart:convert';

import 'package:inspectra/src/config/config_entry.dart';
import 'package:inspectra/src/config/config_layer.dart';
import 'package:inspectra/src/config/config_layer_stack.dart';
import 'package:inspectra/src/config/config_origin.dart';
import 'package:inspectra/src/config/config_policy.dart';
import 'package:inspectra/src/config/config_recorder.dart';
import 'package:inspectra/src/config/config_strictness.dart';
import 'package:inspectra/src/config/config_suggestion.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';

/// The options whose entries every layer adds to, which therefore cannot be
/// locked.
const _collected = <String>{'ignore', 'dependency_policy.denied'};

/// Checks the effective configuration in [effective] against the policy of
/// every layer of [stack].
///
/// A policy binds everything above its file: the files extending it,
/// `INSPECTRA_*` variables and the command line. [parseStack] parses a
/// layer with its own bases, without overrides and policies, and returns
/// what it recorded; it is the reference for locked options.
///
/// Throws an [InspectraConfigException] for a malformed policy and for the
/// first option that violates one.
void checkConfigPolicies(
  ConfigLayerStack stack,
  ConfigRecorder effective,
  ConfigRecorder Function(List<ConfigLayer> layers) parseStack,
) {
  final known = <String>[
    for (final ConfigEntry entry in effective.entries) entry.key,
  ];
  for (var index = 0; index < stack.layers.length; index++) {
    final ConfigLayer layer = stack.layers[index];
    final policy = ConfigPolicy.of(layer);
    if (policy.isEmpty) {
      continue;
    }
    _validate(layer, policy, known);
    if (policy.locked.isNotEmpty) {
      final ConfigRecorder reference = _reference(
        layer,
        () => parseStack(stack.stackOf(index)),
      );
      for (final String key in policy.locked) {
        final ConfigEntry? actual = effective[key];
        final Object? expected = reference[key]?.value;
        if (jsonEncode(actual?.value) != jsonEncode(expected)) {
          throw InspectraConfigException(
            key,
            'locked to ${_show(expected)} by ${layer.label}; got '
            '${_show(actual?.value)} from ${_origin(actual, effective)}.',
          );
        }
      }
    }
    for (final MapEntry<String, Object?> limit in policy.minimum.entries) {
      final ConfigStrictness? order = ConfigStrictness.of(limit.key);
      final ConfigEntry? actual = effective[limit.key];
      final double? rank = order?.rankOf(actual?.value);
      final double? floor = order?.rankOf(limit.value);
      if (rank == null || floor == null || rank >= floor) {
        continue;
      }
      throw InspectraConfigException(
        limit.key,
        '${_show(actual?.value)} (${_origin(actual, effective)}) is below '
        'the minimum ${_show(limit.value)} set by ${layer.label}.',
      );
    }
  }
}

/// Rejects options of [policy] in [layer] that the configuration does not
/// know, that cannot be locked, or whose minimum is no valid value.
///
/// Throws an [InspectraConfigException] naming the entry of the policy.
void _validate(ConfigLayer layer, ConfigPolicy policy, List<String> known) {
  final String? file = layer.isBase ? layer.label : null;
  final String path = ConfigPolicy.pathIn(layer, 'policy');
  for (var index = 0; index < policy.locked.length; index++) {
    final String key = policy.locked[index];
    final at = '$path.locked[$index]';
    _ensureKnown(key, at, known, file);
    if (_collected.contains(key)) {
      throw InspectraConfigException(
        at,
        '$key collects the entries of every file and cannot be locked.',
        file: file,
      );
    }
  }
  for (final MapEntry<String, Object?> limit in policy.minimum.entries) {
    final at = '$path.minimum.${limit.key}';
    _ensureKnown(limit.key, at, known, file);
    final ConfigStrictness? order = ConfigStrictness.of(limit.key);
    if (order == null) {
      throw InspectraConfigException(
        at,
        '${limit.key} has no order from weak to strict; lock it instead.',
        file: file,
      );
    }
    final bool valid = limit.value != null && order.rankOf(limit.value) != null;
    if (!valid) {
      throw InspectraConfigException(
        at,
        '${_show(limit.value)} is no value of ${limit.key}.',
        file: file,
      );
    }
  }
}

/// Rejects the option [key] at [at] of [file] unless it is [known].
///
/// Throws an [InspectraConfigException] with the closest known option.
void _ensureKnown(String key, String at, List<String> known, String? file) {
  if (known.contains(key)) {
    return;
  }
  throw InspectraConfigException(
    at,
    'unknown option $key.${didYouMean(key, known)}',
    file: file,
  );
}

/// Parses [layer] with its own bases through [parse].
///
/// Returns what the parse recorded.
///
/// Throws an [InspectraConfigException] when the layer is not valid on its
/// own.
ConfigRecorder _reference(ConfigLayer layer, ConfigRecorder Function() parse) {
  try {
    return parse();
  } on InspectraConfigException catch (error) {
    throw InspectraConfigException(
      error.path,
      'the base ${layer.label} with its policy is not valid on its own: '
      '${error.message}',
      file: error.file,
    );
  }
}

/// Returns [value] for a message: unset values as such.
String _show(Object? value) =>
    value == null ? 'unset (the default)' : jsonEncode(value);

/// Describes where the effective value of [entry] comes from.
String _origin(ConfigEntry? entry, ConfigRecorder recorder) {
  if (entry == null) {
    return 'the default';
  }
  final String file = entry.file ?? recorder.source ?? 'the configuration';
  final int? line = entry.line;
  return switch (entry.origin) {
    ConfigOrigin.defaults => 'the default',
    ConfigOrigin.file => line == null ? file : '$file:$line',
    ConfigOrigin.environment =>
      'environment variable ${entry.variable ?? 'INSPECTRA_*'}',
    ConfigOrigin.commandLine => 'the command line',
  };
}
