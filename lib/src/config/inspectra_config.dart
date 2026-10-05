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

import 'package:inspectra/src/config/api_config.dart';
import 'package:inspectra/src/config/baseline_config.dart';
import 'package:inspectra/src/config/changelog_config.dart';
import 'package:inspectra/src/config/config_overrides.dart';
import 'package:inspectra/src/config/config_recorder.dart';
import 'package:inspectra/src/config/coverage_config.dart';
import 'package:inspectra/src/config/dependency_policy_config.dart';
import 'package:inspectra/src/config/format_config.dart';
import 'package:inspectra/src/config/ignore_rule.dart';
import 'package:inspectra/src/config/inspect_config.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/config/lint_config.dart';
import 'package:inspectra/src/config/network_config.dart';
import 'package:inspectra/src/config/style_config.dart';
import 'package:inspectra/src/config/trivy_config.dart';
import 'package:inspectra/src/config/trust_thresholds.dart';
import 'package:inspectra/src/config/typosquat_config.dart';
import 'package:inspectra/src/config/yaml_reader.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:yaml/yaml.dart';

export 'package:inspectra/src/changelog/changelog_section.dart';
export 'package:inspectra/src/config/api_config.dart';
export 'package:inspectra/src/config/baseline_config.dart';
export 'package:inspectra/src/config/build_scan_config.dart';
export 'package:inspectra/src/config/changelog_config.dart';
export 'package:inspectra/src/config/config_entry.dart';
export 'package:inspectra/src/config/config_kind.dart';
export 'package:inspectra/src/config/config_origin.dart';
export 'package:inspectra/src/config/config_override.dart';
export 'package:inspectra/src/config/config_recorder.dart';
export 'package:inspectra/src/config/coverage_config.dart';
export 'package:inspectra/src/config/coverage_runner.dart';
export 'package:inspectra/src/config/denied_package.dart';
export 'package:inspectra/src/config/dependency_policy_config.dart';
export 'package:inspectra/src/config/filesystem_scan_config.dart';
export 'package:inspectra/src/config/format_config.dart';
export 'package:inspectra/src/config/ignore_rule.dart';
export 'package:inspectra/src/config/inspect_config.dart';
export 'package:inspectra/src/config/license_scan_config.dart';
export 'package:inspectra/src/config/lint_config.dart';
export 'package:inspectra/src/config/lint_level.dart';
export 'package:inspectra/src/config/network_config.dart';
export 'package:inspectra/src/config/scan_config.dart';
export 'package:inspectra/src/config/secret_scan_config.dart';
export 'package:inspectra/src/config/style_config.dart';
export 'package:inspectra/src/config/trivy_config.dart';
export 'package:inspectra/src/config/trivy_mode.dart';
export 'package:inspectra/src/config/trust_thresholds.dart';
export 'package:inspectra/src/config/typosquat_config.dart';
export 'package:inspectra/src/config/vulnerability_scan_config.dart';
export 'package:inspectra/src/style/style_preset.dart';

/// The name of the dedicated configuration file in the package root.
const configFileName = 'inspectra.yaml';

/// The key of the configuration section inside `pubspec.yaml`.
const pubspecSectionKey = 'inspectra';

/// The complete Inspectra configuration of one package.
///
/// It is read from `inspectra.yaml` in the package root when that file
/// exists, and otherwise from the `inspectra:` section of `pubspec.yaml`.
/// Both hold the same keys. Every option can be overridden with an
/// `INSPECTRA_*` environment variable or on the command line (see
/// [ConfigOverrides]).
///
/// The quality features (`format`, `lint`, `style`, `api`, `trivy` scans,
/// `coverage`, `changelog`) are opt-in. The supply-chain commands (`scan`,
/// `audit`, `inspect`, `trust`, `typosquat`, `add`, `hook`) and changelog
/// generation work without any configuration; the supply-chain commands
/// are tuned by `fail_on`, `min_severity`, `ignore`, `network`, `inspect`,
/// `trust`, `typosquat` and the provisioning keys of `trivy`. `baseline`
/// names the file of accepted findings that `scan`, `audit`, `typosquat`,
/// `trivy`, `lint`, `style` and `check` do not report.
final class InspectraConfig {
  /// Creates a configuration from its parts.
  const InspectraConfig({
    required this.packageName,
    required this.format,
    required this.lint,
    required this.trivy,
    required this.api,
    required this.coverage,
    this.changelog = const ChangelogConfig(),
    this.style = const StyleConfig(),
    this.failOn,
    this.minSeverity = Severity.unknown,
    this.ignore = const <IgnoreRule>[],
    this.network = const NetworkConfig(),
    this.inspect = const InspectConfig(),
    this.trust = const TrustThresholds(),
    this.typosquat = const TyposquatConfig(),
    this.baseline = const BaselineConfig(),
    this.dependencyPolicy = const DependencyPolicyConfig(),
  });

  /// The configuration with every default, for the package [packageName].
  ///
  /// Returns the default configuration.
  factory InspectraConfig.defaults(String packageName) =>
      InspectraConfig.parse(null, packageName: packageName);

  /// Parses the configuration mapping [node], which lives at [path], with
  /// the [overrides] layered on top; a [recorder] records every value with
  /// its origin.
  ///
  /// Returns the configuration.
  ///
  /// Throws an [InspectraConfigException] for an unknown key or a value of
  /// the wrong type.
  factory InspectraConfig.parse(
    Object? node, {
    required String packageName,
    String path = '',
    ConfigOverrides? overrides,
    ConfigRecorder? recorder,
  }) {
    final ConfigOverrides layers = overrides ?? ConfigOverrides.none();
    final root = YamlReader(
      node,
      path,
      overrides: layers,
      keyPath: '',
      recorder: recorder,
    );
    final severities = <String, Severity?>{
      for (final severity in Severity.values) severity.name: severity,
    };
    final config = InspectraConfig(
      packageName: packageName,
      format: FormatConfig.fromYaml(root.section('format')),
      lint: LintConfig.fromYaml(root.section('lint')),
      style: StyleConfig.fromYaml(root.section('style')),
      trivy: TrivyConfig.fromYaml(root.section('trivy')),
      api: ApiConfig.fromYaml(root.section('api'), packageName),
      coverage: CoverageConfig.fromYaml(root.section('coverage')),
      changelog: ChangelogConfig.fromYaml(root.section('changelog')),
      failOn: root.choice('fail_on', severities, fallback: null),
      minSeverity:
          root.choice('min_severity', severities, fallback: Severity.unknown) ??
          Severity.unknown,
      ignore: IgnoreRule.listFromYaml(root),
      network: NetworkConfig.fromYaml(root.section('network')),
      inspect: InspectConfig.fromYaml(root.section('inspect')),
      trust: TrustThresholds.fromYaml(root.section('trust')),
      typosquat: TyposquatConfig.fromYaml(root.section('typosquat')),
      baseline: BaselineConfig.fromYaml(root.section('baseline')),
      dependencyPolicy: DependencyPolicyConfig.fromYaml(
        root.section('dependency_policy'),
      ),
    );
    root.ensureFullyRead();
    layers.ensureAllConsumed();
    return config;
  }

  /// Reads the configuration from the text of the package's files.
  ///
  /// [pubspec] is the content of `pubspec.yaml`, or `null` outside of a
  /// package; [configFile] that of `inspectra.yaml`, or `null` when there
  /// is none, and wins when both are present. A [recorder] records every
  /// value with its origin and the file it was read from.
  ///
  /// Returns the configuration.
  ///
  /// Throws an [InspectraConfigException] when the files are malformed or
  /// the package has no name.
  factory InspectraConfig.fromSources({
    required String? pubspec,
    String? configFile,
    String configFileLabel = configFileName,
    ConfigOverrides? overrides,
    ConfigRecorder? recorder,
  }) {
    final Object? pubspecYaml = pubspec == null
        ? null
        : _load(pubspec, 'pubspec.yaml');
    final Object? name = pubspecYaml is Map ? pubspecYaml['name'] : null;
    if (pubspec != null && name is! String) {
      throw const InspectraConfigException(
        'pubspec.yaml',
        'the package has no name.',
      );
    }
    final String packageName = name is String ? name : 'package';
    if (configFile != null) {
      recorder?.source = configFileLabel;
      return InspectraConfig.parse(
        _load(configFile, configFileLabel),
        packageName: packageName,
        overrides: overrides,
        recorder: recorder,
      );
    }
    final Object? section = pubspecYaml is Map
        ? pubspecYaml[pubspecSectionKey]
        : null;
    recorder?.source = section == null ? null : 'pubspec.yaml';
    return InspectraConfig.parse(
      section,
      packageName: packageName,
      path: section == null ? '' : pubspecSectionKey,
      overrides: overrides,
      recorder: recorder,
    );
  }

  /// Parses the YAML [text] of the file [source].
  ///
  /// Returns the document.
  ///
  /// Throws an [InspectraConfigException] naming the line and column of a
  /// syntax error.
  static Object? _load(String text, String source) {
    try {
      return loadYaml(text, sourceUrl: Uri.file(source));
    } on YamlException catch (error) {
      final int? line = error.span?.start.line;
      final int? column = error.span?.start.column;
      final location = line == null || column == null
          ? ''
          : 'line ${line + 1}, column ${column + 1}: ';
      throw InspectraConfigException(source, '$location${error.message}');
    }
  }

  /// The name of the package this configuration belongs to.
  final String packageName;

  /// The formatting check.
  final FormatConfig format;

  /// The static analysis check.
  final LintConfig lint;

  /// The style check.
  final StyleConfig style;

  /// The Trivy scans and how Trivy is provisioned.
  final TrivyConfig trivy;

  /// Public API validation.
  final ApiConfig api;

  /// The test coverage gate.
  final CoverageConfig coverage;

  /// Changelog generation and validation.
  final ChangelogConfig changelog;

  /// The minimum severity that makes a supply-chain command exit with `1`,
  /// or `null` to use the command's own default (any finding for `audit`
  /// and `scan`, `HIGH` for `typosquat`, `CRITICAL` for `trust`).
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

  /// The baseline of accepted findings.
  final BaselineConfig baseline;

  /// The rules for the dependencies of the package.
  final DependencyPolicyConfig dependencyPolicy;
}
