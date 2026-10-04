import 'package:args/args.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/inspectra_command.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/trivy/configured_scans_report.dart';
import 'package:inspectra/src/trivy/trivy_command.dart';
import 'package:inspectra/src/trivy/trivy_outcome.dart';
import 'package:inspectra/src/trivy/trivy_provision.dart';
import 'package:inspectra/src/trivy/trivy_report.dart';

/// `inspectra trivy [scans...]`: runs Trivy, locating or downloading it as
/// configured.
///
/// * With scan names (`secret`, `license`, `vulnerability`, `filesystem`) or
///   with `trivy.enabled: true`, the configured scans run, each with its own
///   settings and JSON report in `trivy.report_directory`.
/// * Otherwise one `trivy fs` scan of the package runs with the scanners of
///   `trivy.filesystem`.
/// * `--install` and `--where` only provision Trivy and report it.
final class TrivyCommand extends InspectraCommand {
  /// Creates the command.
  TrivyCommand(super.context) : super(withTrivyOptions: true) {
    argParser
      ..addFlag(
        'install',
        negatable: false,
        help: 'Only make Trivy available (for example to warm a CI cache).',
      )
      ..addFlag(
        'where',
        negatable: false,
        help: 'Only print which Trivy executable would be used.',
      );
  }

  /// The command name.
  @override
  String get name => 'trivy';

  /// The one line description.
  @override
  String get description =>
      'Run Trivy: the configured scans, or a filesystem scan of the package.';

  /// The positional arguments.
  @override
  String get invocation {
    final scans = TrivyScan.values.map((scan) => scan.name).join('|');
    return 'inspectra trivy [$scans...] [options]';
  }

  /// Provisions and runs Trivy.
  ///
  /// Returns the report.
  ///
  /// Throws an [InvalidUsageException] for unknown scan names and an
  /// [UnavailableException] when configured scans need an unavailable
  /// Trivy.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    final root = session.workingDirectory;
    final display = session.display(root);
    final named = _scans(results.rest);
    final provisionOnly =
        results['install'] == true || results['where'] == true;
    if (provisionOnly) {
      final provision = await session.trivyProvisioner().provision(
        onStatus: session.console.info,
      );
      return TrivyReport(
        target: display,
        outcome: TrivyOutcome(provision: provision, findings: const []),
        findings: const <Finding>[],
        provisionOnly: true,
      );
    }
    if (named.isNotEmpty || session.config.trivy.enabled) {
      return _configuredScans(session, named);
    }
    final outcome = await session.trivyService().scan(
      root,
      displayPrefix: display,
      onStatus: session.console.info,
    );
    final filtered = session.filter().apply(outcome.findings);
    return TrivyReport(
      target: display,
      outcome: outcome,
      findings: filtered.kept,
    );
  }

  /// Runs the configured scans, or only the [named] ones.
  ///
  /// Returns the report.
  ///
  /// Throws an [UnavailableException] when Trivy is unavailable.
  Future<CommandReport> _configuredScans(
    CommandSession session,
    Set<TrivyScan> named,
  ) async {
    final provision = await session.trivyProvisioner().provision(
      onStatus: session.console.info,
    );
    final outcome = TrivyOutcome(provision: provision, findings: const []);
    switch (provision) {
      case TrivyUnavailable(:final reason):
        throw UnavailableException(reason);
      case TrivyAvailable(:final executable):
        final scanResults = await runTrivyScans(
          session.config,
          session.workingDirectory,
          only: named.isEmpty ? null : named,
          executable: executable,
        );
        return ConfiguredScansReport(results: scanResults, outcome: outcome);
    }
  }

  /// Parses the scan names in [arguments].
  ///
  /// Returns the selected scans.
  ///
  /// Throws an [InvalidUsageException] for unknown names.
  Set<TrivyScan> _scans(List<String> arguments) {
    final scans = <TrivyScan>{};
    for (final argument in arguments) {
      final scan = TrivyScan.values.where((s) => s.name == argument);
      if (scan.isEmpty) {
        throw InvalidUsageException(
          'Unknown scan "$argument". Known scans: '
          '${TrivyScan.values.map((s) => s.name).join(', ')}.',
        );
      }
      scans.add(scan.first);
    }
    return scans;
  }
}
