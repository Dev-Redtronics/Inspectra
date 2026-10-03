/// Thrown when an Inspectra configuration is malformed.
///
/// The message names the offending key by its full path, for example
/// `inspectra.trivy.secret.severity[1]`, so that a typo is reported where it
/// was made instead of surfacing later as a scan that silently did nothing.
class InspectraConfigException implements Exception {
  /// Creates an exception for the key at [path].
  const InspectraConfigException(this.path, this.message);

  /// The dotted path of the offending key.
  final String path;

  /// What is wrong with the value at [path].
  final String message;

  @override
  String toString() => 'Invalid Inspectra configuration at "$path": $message';
}
