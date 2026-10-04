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

import 'package:args/args.dart';

import '../../model/inspectra_exception.dart';
import '../../model/severity.dart';
import '../../pub/package_name.dart';
import '../../report/command_report.dart';
import '../../trust/trust_report.dart';
import '../command_session.dart';
import '../inspectra_command.dart';

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
    final name = PackageName.validate(results.rest[0]);
    final version = results.rest.length > 1
        ? PackageName.validateExactVersion(results.rest[1])
        : null;
    session.console.info('Checking trust metadata for $name...');
    final info = await session.trustAssessor().assessByName(
      name,
      version: version,
    );
    if (info == null) {
      throw InvalidUsageException(
        'Package "$name" was not found on '
        '${session.config.network.pubHostedUrl}.',
      );
    }
    final outcome = session.filter().apply(info.findings);
    return TrustReport(
      info: info,
      findings: outcome.kept,
      now: session.context.clock.now(),
    );
  }
}
