/*
 * Copyright 2026 Redtronics
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

import '../model/severity.dart';
import 'ignore_rule.dart';
import 'inspect_config.dart';
import 'network_config.dart';
import 'trivy_config.dart';
import 'trust_thresholds.dart';
import 'typosquat_config.dart';

/// The complete, validated configuration of one Inspectra run.
///
/// It is assembled by `ConfigLoader` from, in increasing precedence: built-in
/// defaults, `inspectra.yaml`, `INSPECTRA_*` environment variables and
/// command line flags.
final class InspectraConfig {
  /// Creates a configuration; every section defaults to its built-in values.
  const InspectraConfig({
    this.failOn,
    this.minSeverity = Severity.unknown,
    this.ignore = const <IgnoreRule>[],
    this.network = const NetworkConfig(),
    this.inspect = const InspectConfig(),
    this.trust = const TrustThresholds(),
    this.typosquat = const TyposquatConfig(),
    this.trivy = const TrivyConfig(),
  });

  /// The minimum severity that makes a command exit with `1`, or `null` to
  /// use the command's own default (any finding for `audit`, `HIGH` for
  /// `typosquat`, `CRITICAL` for `trust`).
  final Severity? failOn;

  /// Findings below this severity are not reported at all.
  final Severity minSeverity;

  /// Documented suppressions.
  final List<IgnoreRule> ignore;

  /// Network settings.
  final NetworkConfig network;

  /// Source inspector settings.
  final InspectConfig inspect;

  /// Trust assessment thresholds.
  final TrustThresholds trust;

  /// Typosquat detector settings.
  final TyposquatConfig typosquat;

  /// Trivy integration settings.
  final TrivyConfig trivy;
}
