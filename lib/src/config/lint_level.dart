/// The lowest severity of a `dart analyze` diagnostic that fails the check.
enum LintLevel {
  /// Only errors fail.
  error,

  /// Errors and warnings fail.
  warning,

  /// Errors, warnings and infos - including every lint - fail, like
  /// `dart analyze --fatal-infos`.
  info,

  /// Nothing fails; diagnostics are only reported.
  none,
}
