/*
 * Copyright 2026 Redtronics
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/// The root of every expected failure that Inspectra reports to its user.
///
/// The hierarchy is sealed so that the command runner can map each failure to
/// its process exit code with an exhaustive `switch`: adding a new kind of
/// failure is a compile error until its exit code has been decided. Anything
/// that is not an [InspectraException] is an internal error.
sealed class InspectraException implements Exception {
  /// Creates an exception carrying a [message] that is shown to the user
  /// verbatim, so it must be a complete, actionable sentence.
  const InspectraException(this.message);

  /// The user facing explanation of the failure.
  final String message;

  /// Returns the [message], which is what the command line prints.
  @override
  String toString() => message;
}

/// The command line was used incorrectly, for example a required positional
/// argument is missing. Maps to exit code `64` (`EX_USAGE`).
final class InvalidUsageException extends InspectraException {
  /// Creates a usage failure with a user facing [message].
  const InvalidUsageException(super.message);
}

/// An input file or value is malformed, for example an unparsable
/// `pubspec.lock` or an invalid configuration key. Maps to exit code `65`
/// (`EX_DATAERR`).
final class InvalidInputException extends InspectraException {
  /// Creates an input failure with a user facing [message].
  const InvalidInputException(super.message);
}

/// A remote service or external tool that the verification depends on is not
/// available, so the result would be incomplete. Maps to exit code `69`
/// (`EX_UNAVAILABLE`).
///
/// This is never downgraded by `--exit-zero`: a verification that did not run
/// must not look like a clean result in a CI pipeline.
final class UnavailableException extends InspectraException {
  /// Creates an availability failure with a user facing [message].
  const UnavailableException(super.message);
}
