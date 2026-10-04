import 'package:inspectra/src/config/build_scan_config.dart';
import 'package:inspectra/src/config/scan_config.dart';
import 'package:inspectra/src/config/yaml_reader.dart';
import 'package:inspectra/src/model/severity.dart';

/// The license scan, the `trivy.license:` section.
final class LicenseScanConfig extends BuildScanConfig {
  /// Creates the license scan settings.
  const LicenseScanConfig({
    required super.enabled,
    required super.runOnBuild,
    required super.failOnFindings,
    required super.severity,
    required this.ignoredLicenses,
    required this.ignoredPackages,
    required this.includeDevDependencies,
  });

  /// Reads the settings from the `trivy.license:` section in [yaml].
  ///
  /// Returns the settings.
  ///
  /// Throws an `InspectraConfigException` for unknown keys or invalid
  /// values.
  factory LicenseScanConfig.fromYaml(YamlReader yaml) {
    final config = LicenseScanConfig(
      enabled: yaml.boolean('enabled', fallback: true),
      runOnBuild: yaml.boolean('run_on_build', fallback: false),
      failOnFindings: yaml.boolean('fail_on_findings', fallback: true),
      severity: ScanConfig.readSeverities(yaml, defaultSeverity),
      ignoredLicenses: yaml.strings('ignored_licenses', fallback: const []),
      ignoredPackages: yaml.strings('ignored_packages', fallback: const []),
      includeDevDependencies: yaml.boolean(
        'include_dev_dependencies',
        fallback: false,
      ),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// The settings when nothing is configured.
  static const LicenseScanConfig defaults = LicenseScanConfig(
    enabled: true,
    runOnBuild: false,
    failOnFindings: true,
    severity: defaultSeverity,
    ignoredLicenses: <String>[],
    ignoredPackages: <String>[],
    includeDevDependencies: false,
  );

  /// The severities reported by default: forbidden, restricted and
  /// unclassified licenses.
  static const List<Severity> defaultSeverity = <Severity>[
    Severity.critical,
    Severity.high,
    Severity.unknown,
  ];

  /// SPDX identifiers of licenses that are never reported.
  final List<String> ignoredLicenses;

  /// Names of packages whose license is never reported.
  final List<String> ignoredPackages;

  /// Whether `dev_dependencies` are checked too.
  ///
  /// Off by default: a license binds what is shipped, and a package that
  /// only your tests or your build use never reaches a consumer.
  final bool includeDevDependencies;
}
