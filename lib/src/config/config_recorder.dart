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

import 'package:inspectra/src/config/config_entry.dart';
import 'package:inspectra/src/config/config_layer.dart';

/// Collects the effective value and origin of every configuration option
/// while a configuration is parsed.
///
/// Pass one to `loadConfig` or `InspectraConfig.parse`; afterwards
/// [entries] lists every option that was read, in the order of the
/// configuration file layout.
final class ConfigRecorder {
  /// Creates an empty recorder.
  ConfigRecorder();

  /// The entries keyed by option, in the order they were first read.
  final _entries = <String, ConfigEntry>{};

  /// The configuration file the values were read from, such as
  /// `inspectra.yaml` or `pubspec.yaml`, or `null` without one.
  String? source;

  /// The layers of the configuration, from the lowest to the highest
  /// precedence; empty when it extends no base.
  var layers = const <ConfigLayer>[];

  /// Every recorded option, in the order it was first read.
  List<ConfigEntry> get entries =>
      List<ConfigEntry>.unmodifiable(_entries.values);

  /// Records [entry]; a later entry of the same key replaces an earlier
  /// one but keeps its position.
  void record(ConfigEntry entry) => _entries[entry.key] = entry;

  /// Returns the entry of the dotted [key], or `null` when it was not read.
  ConfigEntry? operator [](String key) => _entries[key];
}
