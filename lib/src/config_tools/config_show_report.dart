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
import 'package:inspectra/src/config/config_origin.dart';
import 'package:inspectra/src/config_tools/config_yaml_writer.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/command_report.dart';

/// The report of `config show`: the effective configuration.
///
/// The text is the configuration as YAML; the JSON body has `source`, the
/// configuration file or `null`, `layers`, the bases and the project's file
/// from the lowest to the highest precedence when there are bases, and
/// `values`, one object per option with `key`, `value`, `default`, `origin`
/// and, where known, `variable`, `file` and `line`.
final class ConfigShowReport implements CommandReport {
  /// Creates the report of the [entries] read from [source]; [explain]
  /// comments every value with its origin and [onlyChanged] leaves out the
  /// values that are the defaults.
  const ConfigShowReport({
    required this.entries,
    required this.source,
    this.layers = const <ConfigLayer>[],
    this.explain = false,
    this.onlyChanged = false,
  });

  /// Every option of the configuration.
  final List<ConfigEntry> entries;

  /// The configuration file, or `null` without one.
  final String? source;

  /// The layers of the configuration, from the lowest to the highest
  /// precedence; empty when it extends no base.
  final List<ConfigLayer> layers;

  /// Whether every value is commented with its origin.
  final bool explain;

  /// Whether only values that differ from the defaults are shown.
  final bool onlyChanged;

  /// The options shown.
  List<ConfigEntry> get shown => onlyChanged
      ? entries
            .where((entry) => entry.origin != ConfigOrigin.defaults)
            .where((entry) => entry.value != null)
            .toList()
      : entries;

  /// The name of the command.
  @override
  String get command => 'config show';

  /// Showing the configuration never reports findings.
  @override
  List<Finding> get findings => const <Finding>[];

  /// Showing the configuration never fails because of findings.
  ///
  /// Returns `false`.
  @override
  bool isFailing(Severity threshold) => false;

  /// Builds the JSON body.
  ///
  /// Returns the JSON body.
  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'source': source,
    'layers': <Map<String, Object?>>[
      for (final ConfigLayer layer in layers) layer.toJson(),
    ],
    'values': <Map<String, Object?>>[for (final entry in shown) entry.toJson()],
  };

  /// Writes the configuration as YAML.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    final List<ConfigEntry> visible = shown;
    if (visible.isEmpty) {
      out.writeln('# Every option has its default value.');
      return;
    }
    final int bases = layers.isEmpty ? 0 : layers.length - 1;
    final extended = bases == 0 ? '' : ', $bases base(s)';
    final origin = source == null && bases == 0
        ? 'built-in defaults'
        : '${source ?? 'no file'}$extended and its overrides';
    out
      ..writeln('# The effective Inspectra configuration: $origin.')
      ..write(writeConfigYaml(visible, explain: explain, source: source));
  }
}
