import 'package:inspectra/src/cli/package_check_command.dart';

/// `inspectra check`: runs every enabled package check — format, lint,
/// API, the configured Trivy scans and coverage.
final class CheckCommand extends PackageCheckCommand {
  /// Creates the command.
  CheckCommand(super.context);

  /// The command name.
  @override
  String get name => 'check';

  /// The one line description.
  @override
  String get description =>
      'Run every enabled package check: format, lint, API, Trivy scans and '
      'coverage.';

  /// Runs the enabled checks one after the other.
  ///
  /// Returns whether all of them passed.
  @override
  Future<bool> runChecks() async {
    final config = loadPackageConfig();
    final steps = <(bool, Future<bool> Function())>[
      (config.format.enabled, () => runFormat(config)),
      (config.lint.enabled, () => runLintGate(config)),
      (config.api.enabled, () => runApiCheck(config)),
      (config.trivy.enabled, () => runScans(config)),
      (config.coverage.enabled, () => runCoverageGate(config)),
    ];
    final enabled = steps.where((step) => step.$1).toList();
    if (enabled.isEmpty) {
      out.writeln(
        'Nothing is enabled. Enable "format", "lint", "api", "trivy" or '
        '"coverage" in the Inspectra configuration.',
      );
      return true;
    }
    var passed = true;
    for (final (_, check) in enabled) {
      passed = await check() && passed;
    }
    return passed;
  }
}
