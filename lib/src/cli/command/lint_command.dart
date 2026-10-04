import 'package:inspectra/src/cli/package_check_command.dart';

/// `inspectra lint`: analyzes the package with its analysis options.
final class LintCommand extends PackageCheckCommand {
  /// Creates the command.
  LintCommand(super.context) {
    argParser.addFlag(
      'fix',
      negatable: false,
      help: 'Apply "dart fix --apply" before analyzing.',
    );
  }

  /// The command name.
  @override
  String get name => 'lint';

  /// The one line description.
  @override
  String get description =>
      'Analyze the package with the rules of analysis_options.yaml.';

  /// Runs the lint check.
  ///
  /// Returns whether it passed.
  @override
  Future<bool> runChecks() =>
      runLintGate(loadPackageConfig(), fix: argResults?.flag('fix') ?? false);
}
