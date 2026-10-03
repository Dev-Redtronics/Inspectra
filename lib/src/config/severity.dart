/// A Trivy severity level.
///
/// The same five levels apply to every scan: Trivy rates vulnerabilities and
/// secrets from [critical] to [low], and maps license categories onto them
/// (`forbidden` is [critical], `restricted` [high], `reciprocal` [medium],
/// `notice` and `permissive` [low]). [unknown] is what a license gets that
/// could not be classified.
enum Severity {
  /// Requires immediate attention.
  critical,

  /// Should be addressed as soon as possible.
  high,

  /// Important, but not urgent.
  medium,

  /// Minimal impact.
  low,

  /// Could not be rated.
  unknown;

  /// The spelling Trivy uses on its command line and in its reports.
  String get trivyName => name.toUpperCase();

  /// Parses [value] case-insensitively, or returns `null`.
  static Severity? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    for (final Severity severity in values) {
      if (severity.name == normalized) {
        return severity;
      }
    }
    return null;
  }

  /// The accepted spellings, for error messages.
  static String get expected =>
      values.map((severity) => severity.trivyName).join(', ');
}
