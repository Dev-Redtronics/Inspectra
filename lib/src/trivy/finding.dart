import 'package:inspectra/src/model/severity.dart';

/// One issue a scan reported.
class ScanFinding {
  /// Creates a finding.
  const ScanFinding({
    required this.severity,
    required this.target,
    required this.id,
    required this.title,
    this.detail,
  });

  /// How severe the issue is.
  final Severity severity;

  /// Where the issue was found: a file, or a package with its version.
  final String target;

  /// The rule, vulnerability or license identifier.
  final String id;

  /// A one-line description.
  final String title;

  /// Further information, such as the fixed version or a line number.
  final String? detail;

  /// Serializes this finding for the JSON report.
  Map<String, Object?> toJson() => {
    'severity': severity.trivyName,
    'target': target,
    'id': id,
    'title': title,
    if (detail != null) 'detail': detail,
  };
}

/// The outcome of one scan.
class ScanResult {
  /// Creates the outcome of the scan named [scan].
  ScanResult({
    required this.scan,
    required List<ScanFinding> findings,
    required this.failOnFindings,
    this.skipped,
  }) : findings = List<ScanFinding>.unmodifiable(
         <ScanFinding>[...findings]..sort((a, b) {
           final int bySeverity = a.severity.index.compareTo(b.severity.index);
           if (bySeverity != 0) {
             return bySeverity;
           }
           final int byTarget = a.target.compareTo(b.target);
           if (byTarget != 0) {
             return byTarget;
           }
           return a.id.compareTo(b.id);
         }),
       );

  /// A scan that did not run, and why.
  ScanResult.skipped({required this.scan, required String reason})
    : findings = const [],
      failOnFindings = false,
      skipped = reason;

  /// The name of the scan, such as `secret`.
  final String scan;

  /// What the scan reported, most severe first.
  final List<ScanFinding> findings;

  /// Whether [findings] make the scan fail.
  final bool failOnFindings;

  /// Why the scan did not run, or `null` when it did.
  final String? skipped;

  /// Whether the scan failed.
  bool get failed => failOnFindings && findings.isNotEmpty;

  /// A readable summary for the console or the build log.
  String render() {
    if (skipped != null) {
      return 'Trivy $scan scan skipped: $skipped';
    }
    if (findings.isEmpty) {
      return 'Trivy $scan scan: no findings.';
    }

    final suffix = failed ? '' : ' (not failing)';
    final buffer = StringBuffer()
      ..writeln('Trivy $scan scan: ${findings.length} finding(s)$suffix.');
    for (final ScanFinding finding in findings) {
      buffer.write(
        '  [${finding.severity.trivyName}] ${finding.target}: '
        '${finding.id} - ${finding.title}',
      );
      if (finding.detail != null) {
        buffer.write(' (${finding.detail})');
      }
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }

  /// Serializes this result for the JSON report.
  Map<String, Object?> toJson() => {
    'scan': scan,
    'failed': failed,
    if (skipped != null) 'skipped': skipped,
    'findings': [for (final finding in findings) finding.toJson()],
  };
}
