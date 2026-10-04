import 'package:inspectra/src/config/scan_config.dart';

/// Settings of a scan that `build_runner` can run as well.
abstract base class BuildScanConfig extends ScanConfig {
  /// Creates the settings.
  const BuildScanConfig({
    required super.enabled,
    required this.runOnBuild,
    required super.failOnFindings,
    required super.severity,
  });

  /// Whether `dart run build_runner build` runs this scan too.
  ///
  /// Only the secret scan does by default: it reads files that are already
  /// on disk and costs a second. The vulnerability scan downloads Trivy's
  /// database, and the license scan reads the license file of every
  /// dependency, so both run from the command line or in CI unless enabled
  /// here.
  final bool runOnBuild;
}
