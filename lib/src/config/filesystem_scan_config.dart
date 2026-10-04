import 'package:inspectra/src/config/scan_config.dart';
import 'package:inspectra/src/config/yaml_reader.dart';
import 'package:inspectra/src/model/severity.dart';

/// A plain `trivy fs` scan of the package directory, the
/// `trivy.filesystem:` section. The `scan` command uses these scanners,
/// severities and skipped directories as well.
final class FilesystemScanConfig extends ScanConfig {
  /// Creates the filesystem scan settings.
  const FilesystemScanConfig({
    required super.enabled,
    required super.failOnFindings,
    required super.severity,
    required this.scanners,
    required this.skipDirectories,
  });

  /// Reads the settings from the `trivy.filesystem:` section in [yaml].
  ///
  /// Returns the settings.
  ///
  /// Throws an `InspectraConfigException` for unknown keys or invalid
  /// values.
  factory FilesystemScanConfig.fromYaml(YamlReader yaml) {
    final config = FilesystemScanConfig(
      enabled: yaml.boolean('enabled', fallback: false),
      failOnFindings: yaml.boolean('fail_on_findings', fallback: true),
      severity: ScanConfig.readSeverities(yaml, defaultSeverity),
      scanners: yaml.enums(
        'scanners',
        fallback: defaultScanners,
        parse: (value) => supportedScanners.contains(value) ? value : null,
        expected: supportedScanners.join(', '),
      ),
      skipDirectories: yaml.strings(
        'skip_dirs',
        fallback: defaultSkipDirectories,
      ),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// The settings when nothing is configured.
  static const FilesystemScanConfig defaults = FilesystemScanConfig(
    enabled: false,
    failOnFindings: true,
    severity: defaultSeverity,
    scanners: defaultScanners,
    skipDirectories: defaultSkipDirectories,
  );

  /// Every scanner Trivy offers for file system targets.
  static const List<String> supportedScanners = <String>[
    'vuln',
    'secret',
    'misconfig',
    'license',
  ];

  /// The scanners run by default. License scanning is opt-in because Trivy
  /// reports every detected license, including permissive ones.
  static const List<String> defaultScanners = <String>[
    'vuln',
    'secret',
    'misconfig',
  ];

  /// The severities reported by default.
  static const List<Severity> defaultSeverity = <Severity>[
    Severity.critical,
    Severity.high,
    Severity.medium,
    Severity.low,
  ];

  /// The directories skipped by default.
  static const List<String> defaultSkipDirectories = <String>[
    '.dart_tool',
    'build',
    '.git',
  ];

  /// The Trivy scanners to run: `vuln`, `secret`, `misconfig` and `license`.
  ///
  /// `misconfig` is the one only this scan offers: it checks Dockerfiles,
  /// Kubernetes manifests, Terraform and CI definitions in the package.
  final List<String> scanners;

  /// Directories Trivy skips, relative to the package root.
  final List<String> skipDirectories;
}
