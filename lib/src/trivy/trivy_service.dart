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

import 'package:inspectra/src/config/trivy_config.dart';
import 'package:inspectra/src/config/trivy_mode.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/trivy/trivy_outcome.dart';
import 'package:inspectra/src/trivy/trivy_provision.dart';
import 'package:inspectra/src/trivy/trivy_provisioner.dart';
import 'package:inspectra/src/trivy/trivy_runner.dart';

/// Provisions Trivy, applies the configured mode and runs the scan.
final class TrivyService {
  /// Creates a service.
  const TrivyService({
    required this.config,
    required this.provisioner,
    required this.runner,
  });

  /// The Trivy configuration.
  final TrivyConfig config;

  /// Makes Trivy available.
  final TrivyProvisioner provisioner;

  /// Runs Trivy.
  final TrivyRunner runner;

  /// Scans [directory], prefixing reported paths with [displayPrefix].
  ///
  /// [onStatus] receives progress messages. In `auto` mode an unavailable
  /// Trivy is reported through the outcome instead of an exception.
  ///
  /// Returns the outcome.
  ///
  /// Throws an [UnavailableException] when Trivy is unavailable in
  /// `required` mode or when it fails while running.
  Future<TrivyOutcome> scan(
    String directory, {
    required String displayPrefix,
    required void Function(String message) onStatus,
  }) async {
    final TrivyProvision provision = await provisioner.provision(
      onStatus: onStatus,
    );
    switch (provision) {
      case TrivyUnavailable(:final reason):
        if (config.mode == TrivyMode.required) {
          throw UnavailableException(
            '$reason Trivy is required '
            '(trivy.mode: required).',
          );
        }
        return TrivyOutcome(provision: provision, findings: const <Finding>[]);
      case TrivyAvailable(:final executable, :final version):
        onStatus('Running Trivy $version...');
        final List<Finding> findings = await runner.scan(
          executable,
          directory,
          displayPrefix: displayPrefix,
        );
        return TrivyOutcome(provision: provision, findings: findings);
    }
  }
}
