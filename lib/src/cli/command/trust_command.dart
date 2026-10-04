/*
 * Copyright 2026 Davils
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

import 'package:args/args.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/inspectra_command.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/policy/filter_outcome.dart';
import 'package:inspectra/src/pub/package_name.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/trust/trust_info.dart';
import 'package:inspectra/src/trust/trust_report.dart';

/// `inspectra trust <package> [version]`: prints the pub.dev trust
/// assessment of a package version.
final class TrustCommand extends InspectraCommand {
  /// Creates the command.
  TrustCommand(super.context);

  /// The command name.
  @override
  String get name => 'trust';

  /// The one line description.
  @override
  String get description =>
      'Query pub.dev and print a trust assessment for a package.';

  /// The positional arguments.
  @override
  String get invocation => 'inspectra trust <package> [version] [options]';

  /// Only CRITICAL trust findings fail the command, as in `dart_audit`.
  @override
  Severity get defaultFailOn => Severity.critical;

  /// Assesses the package.
  ///
  /// Returns the trust report.
  ///
  /// Throws an [InvalidUsageException] when the package is missing or
  /// unknown.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    if (results.rest.isEmpty) {
      throw const InvalidUsageException(
        'trust requires a <package> '
        'argument.',
      );
    }
    final String name = PackageName.validate(results.rest[0]);
    final String? version = results.rest.length > 1
        ? PackageName.validateExactVersion(results.rest[1])
        : null;
    session.console.info('Checking trust metadata for $name...');
    final TrustInfo? info = await session.trustAssessor().assessByName(
      name,
      version: version,
    );
    if (info == null) {
      throw InvalidUsageException(
        'Package "$name" was not found on '
        '${session.config.network.pubHostedUrl}.',
      );
    }
    final FilterOutcome outcome = session.filter().apply(info.findings);
    return TrustReport(
      info: info,
      findings: outcome.kept,
      now: session.context.clock.now(),
    );
  }
}
