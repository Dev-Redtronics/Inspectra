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

import '../model/inspectra_exception.dart';

/// The process exit codes of Inspectra, following `sysexits.h`.
///
/// `0`, `1` and `64` are identical to `dart_audit`, so existing pipelines
/// keep working; the additional codes let a pipeline tell a finding apart
/// from broken input and from a verification that could not run.
enum ExitCode {
  /// No finding reached the failure threshold.
  success(0),

  /// At least one finding reached the failure threshold.
  findings(1),

  /// The command line was used incorrectly (`EX_USAGE`).
  usage(64),

  /// An input file or configuration value is malformed (`EX_DATAERR`).
  dataError(65),

  /// A required service or tool was not available, so the verification is
  /// incomplete (`EX_UNAVAILABLE`).
  unavailable(69),

  /// An unexpected internal error occurred (`EX_SOFTWARE`).
  software(70);

  /// Creates an exit code with its numeric [code].
  const ExitCode(this.code);

  /// The numeric process exit code.
  final int code;

  /// Maps an expected failure to its exit code.
  ///
  /// Returns the exit code of [error].
  static ExitCode of(InspectraException error) {
    return switch (error) {
      InvalidUsageException() => ExitCode.usage,
      InvalidInputException() => ExitCode.dataError,
      UnavailableException() => ExitCode.unavailable,
    };
  }
}
