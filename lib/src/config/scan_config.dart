import 'package:inspectra/src/config/yaml_reader.dart';
import 'package:inspectra/src/model/severity.dart';

/// Settings shared by every Trivy scan.
abstract base class ScanConfig {
  /// Creates the shared settings.
  const ScanConfig({
    required this.enabled,
    required this.failOnFindings,
    required this.severity,
  });

  /// Reads the `severity` list of a scan section in [yaml].
  ///
  /// Returns the severities, or [fallback] when the list is absent.
  ///
  /// Throws an `InspectraConfigException` for unknown severities.
  static List<Severity> readSeverities(
    YamlReader yaml,
    List<Severity> fallback,
  ) {
    return yaml.enums(
      'severity',
      fallback: fallback,
      parse: Severity.tryParse,
      expected: Severity.expected,
    );
  }

  /// Whether this scan runs when Trivy is enabled.
  final bool enabled;

  /// Whether findings fail the build or the command.
  final bool failOnFindings;

  /// The severities that are reported; anything else is ignored.
  final List<Severity> severity;
}
