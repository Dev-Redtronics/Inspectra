import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/model/source_location.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/trivy/finding.dart';
import 'package:inspectra/src/trivy/trivy_outcome.dart';

/// The report of `inspectra trivy` when it runs the configured scans:
/// secret, license, vulnerability and filesystem.
///
/// Each scan keeps its own `fail_on_findings` setting, so the report fails
/// when any scan failed, independent of `--fail-on`.
final class ConfiguredScansReport implements CommandReport {
  /// Creates a report for the scan [results] run with the Trivy described
  /// by [outcome].
  const ConfiguredScansReport({required this.results, required this.outcome});

  /// The results of the scans, in the order they ran.
  final List<ScanResult> results;

  /// How Trivy was provisioned.
  final TrivyOutcome outcome;

  /// The name of the command.
  @override
  String get command => 'trivy';

  /// Every finding of every scan, normalised.
  @override
  List<Finding> get findings => <Finding>[
    for (final result in results)
      for (final finding in result.findings) _normalise(result.scan, finding),
  ];

  /// Fails when any scan failed under its own settings.
  ///
  /// Returns `true` when the command must exit with `1`.
  @override
  bool isFailing(Severity threshold) => results.any((result) => result.failed);

  /// Builds the JSON body: one entry per scan plus the Trivy provisioning.
  ///
  /// Returns the JSON body.
  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'trivy': outcome.toJson(),
    'scans': results.map((result) => result.toJson()).toList(),
  };

  /// Writes the rendered result of every scan.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    for (final result in results) {
      out.writeln(result.render());
    }
  }

  /// Converts a scan finding of [scan] into the normalised model.
  ///
  /// Returns the finding.
  Finding _normalise(String scan, ScanFinding finding) {
    final detail = finding.detail;
    return Finding(
      ruleId: finding.id,
      source: FindingSource.trivy,
      severity: finding.severity,
      title: finding.title,
      description: detail ?? '',
      location: SourceLocation(finding.target),
      attributes: <String, Object?>{'scan': scan},
    );
  }
}
