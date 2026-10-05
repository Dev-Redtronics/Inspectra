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

import 'package:inspectra/src/config/config_fetch_outcome.dart';
import 'package:inspectra/src/config/config_layer.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/command_report.dart';

/// The report of `config fetch`: the bases of the configuration, all of
/// them available, and the remote ones that were downloaded.
///
/// The JSON body has `bases`, one object per base from the lowest to the
/// highest precedence with `label`, `kind` and `downloaded`.
final class ConfigFetchReport implements CommandReport {
  /// Creates the report of [outcome].
  const ConfigFetchReport(this.outcome);

  /// The layers and the downloaded bases.
  final ConfigFetchOutcome outcome;

  /// The name of the command.
  @override
  String get command => 'config fetch';

  /// Fetching never reports findings.
  @override
  List<Finding> get findings => const <Finding>[];

  /// Fetching never fails because of findings.
  ///
  /// Returns `false`.
  @override
  bool isFailing(Severity threshold) => false;

  /// Returns whether [layer] was downloaded now.
  bool _downloaded(ConfigLayer layer) =>
      outcome.downloaded.any((base) => base.label == layer.label);

  /// Builds the JSON body.
  ///
  /// Returns the JSON body.
  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'bases': <Map<String, Object?>>[
      for (final ConfigLayer layer in outcome.stack.bases)
        <String, Object?>{...layer.toJson(), 'downloaded': _downloaded(layer)},
    ],
  };

  /// Writes one line per base and a summary.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    final List<ConfigLayer> bases = outcome.stack.bases;
    if (bases.isEmpty) {
      out.writeln('The configuration extends no base.');
      return;
    }
    for (final layer in bases) {
      final state = _downloaded(layer) ? 'downloaded' : 'available';
      out.writeln(
        '${style.green('✓')} ${layer.label} '
        '${style.dim('(${layer.kind.id}, $state)')}',
      );
    }
    out.writeln(
      '${bases.length} base(s) ready, ${outcome.downloaded.length} '
      'downloaded.',
    );
  }
}
