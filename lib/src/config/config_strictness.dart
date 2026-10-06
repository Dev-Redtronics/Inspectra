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

import 'package:inspectra/src/config/lint_level.dart';
import 'package:inspectra/src/config/trivy_mode.dart';
import 'package:inspectra/src/model/severity.dart';

/// How the values of an option are ordered from the weakest to the
/// strictest, which a policy's `minimum` compares against.
enum ConfigStrictness {
  /// A number where more is stricter, such as a coverage threshold; unset
  /// is the weakest.
  higherNumber,

  /// A number where less is stricter, such as a limit of libyears; unset,
  /// no limit, is the weakest.
  lowerNumber,

  /// A switch where `true` is stricter, such as an enabled check.
  enabledFlag,

  /// A severity threshold where a lower severity is stricter, such as
  /// `fail_on: low` failing on more than `fail_on: high`; unset is the
  /// weakest.
  severityThreshold,

  /// The level of `lint.fail_on`: `info` is stricter than `warning`,
  /// `error` and `none`.
  lintLevel,

  /// The mode of Trivy: `required` is stricter than `auto` and `disabled`.
  trivyMode;

  /// The switches that are no checks and therefore not ordered.
  static const _unordered = <String>{
    'baseline.enabled',
    'network.offline',
    'trivy.download',
    'trivy.use_installed',
    'trivy.skip_db_update',
    'trivy.vulnerability.ignore_unfixed',
  };

  /// The switches of the dependency policy that turn on a rule.
  static const _policySwitches = <String>{
    'dependency_policy.enabled',
    'dependency_policy.require_upper_bound',
    'dependency_policy.require_publish_to',
    'dependency_policy.lockfile_in_sync',
    'dependency_policy.lockfile_checksums',
    'dependency_policy.check_imports',
    'dependency_policy.overrides.require_reason',
    'workspace_policy.require_membership',
    'workspace_policy.same_sdk',
    'workspace_policy.forbid_cycles',
    'workspace_policy.include_dev_dependencies',
  };

  /// Finds the order of the option [key].
  ///
  /// Returns the order, or `null` when the option's values have none.
  static ConfigStrictness? of(String key) {
    if (_unordered.contains(key)) {
      return null;
    }
    if (key == 'coverage.min_line_coverage') {
      return higherNumber;
    }
    if (key == 'dependency_policy.max_major_behind' ||
        key == 'dependency_policy.max_libyear') {
      return lowerNumber;
    }
    if (key == 'fail_on' ||
        key == 'min_severity' ||
        key == 'baseline.max_severity') {
      return severityThreshold;
    }
    if (key == 'lint.fail_on') {
      return lintLevel;
    }
    if (key == 'trivy.mode') {
      return trivyMode;
    }
    final bool isSwitch =
        key.endsWith('.enabled') ||
        key.endsWith('.fail_on_findings') ||
        key.endsWith('.run_on_build') ||
        key == 'baseline.fail_on_stale' ||
        key.startsWith('style.rules.') ||
        _policySwitches.contains(key);
    return isSwitch ? enabledFlag : null;
  }

  /// Ranks [value], as recorded for the configuration, by strictness.
  ///
  /// Returns a higher number for a stricter value, negative infinity for an
  /// unset one, or `null` when [value] is no value of this order.
  double? rankOf(Object? value) {
    if (value == null) {
      return this == enabledFlag ? null : double.negativeInfinity;
    }
    final String text = '$value'.trim().toLowerCase();
    return switch (this) {
      higherNumber => value is num ? value.toDouble() : double.tryParse(text),
      lowerNumber => _negated(value is num ? value.toDouble() : null, text),
      enabledFlag => value is bool ? (value ? 1 : 0) : null,
      severityThreshold =>
        Severity.values
            .where((severity) => severity.name == text)
            .map((severity) => severity.rank.toDouble())
            .firstOrNull,
      lintLevel => switch (LintLevel.values
          .where((level) => level.name == text)
          .firstOrNull) {
        LintLevel.info => 3,
        LintLevel.warning => 2,
        LintLevel.error => 1,
        LintLevel.none => 0,
        null => null,
      },
      trivyMode => switch (TrivyMode.values
          .where((mode) => mode.id == text)
          .firstOrNull) {
        TrivyMode.required => 2,
        TrivyMode.auto => 1,
        TrivyMode.disabled => 0,
        null => null,
      },
    };
  }

  /// Negates the number [value], or the number written as [text], so that
  /// a lower limit ranks higher.
  ///
  /// Returns the negated number, or `null` when there is none.
  static double? _negated(double? value, String text) {
    final double? number = value ?? double.tryParse(text);
    return number == null ? null : -number;
  }
}
