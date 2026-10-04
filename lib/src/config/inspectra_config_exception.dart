/// A configuration value that is missing, unknown or of the wrong type.
///
/// It names the dotted path of the offending key, for example
/// `trivy.secret.severity[1]`, so that the user can find it in
/// `inspectra.yaml`, the `inspectra:` section of `pubspec.yaml`, an
/// `INSPECTRA_*` environment variable or a command line override. It maps to
/// exit code `65`.
final class InspectraConfigException implements Exception {
  /// Creates an exception for the key at [path] described by [message].
  const InspectraConfigException(this.path, this.message);

  /// The dotted path of the offending key.
  final String path;

  /// What is wrong with the value at [path].
  final String message;

  /// Returns the complete, user facing description.
  @override
  String toString() => 'Invalid Inspectra configuration at "$path": $message';
}
