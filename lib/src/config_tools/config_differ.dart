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
import 'package:inspectra/src/config/config_recorder.dart';
import 'package:inspectra/src/config/config_strictness.dart';
import 'package:inspectra/src/config_tools/config_change.dart';

/// Compares the options recorded in [from] with those in [to].
///
/// Values are compared as people see them, so a reference to an
/// environment variable stays a reference; whether a change is weaker is
/// judged on the resolved values.
///
/// Returns the options whose values differ, in the order of [to] followed
/// by options only [from] knows.
List<ConfigChange> diffConfigs(ConfigRecorder from, ConfigRecorder to) {
  final keys = <String>[
    for (final ConfigEntry entry in to.entries) entry.key,
    for (final ConfigEntry entry in from.entries)
      if (to[entry.key] == null) entry.key,
  ];
  final changes = <ConfigChange>[];
  for (final key in keys) {
    final ConfigEntry? before = from[key];
    final ConfigEntry? after = to[key];
    final bool same =
        jsonEncode(before?.shown) == jsonEncode(after?.shown) &&
        jsonEncode(before?.value) == jsonEncode(after?.value);
    if (same) {
      continue;
    }
    final ConfigStrictness? order = ConfigStrictness.of(key);
    final double? rankBefore = order?.rankOf(before?.value);
    final double? rankAfter = order?.rankOf(after?.value);
    final bool weaker =
        rankBefore != null && rankAfter != null && rankAfter < rankBefore;
    changes.add(
      ConfigChange(
        key: key,
        from: before?.shown,
        to: after?.shown,
        weaker: weaker,
      ),
    );
  }
  return changes;
}
