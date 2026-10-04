import 'package:inspectra/src/cli/package_check_command.dart';

/// `inspectra format`: checks the formatting, or formats with `--fix`.
final class FormatCommand extends PackageCheckCommand {
  /// Creates the command.
  FormatCommand(super.context) {
    argParser.addFlag(
      'fix',
      negatable: false,
      help: 'Format the files instead of only checking them.',
    );
  }

  /// The command name.
  @override
  String get name => 'format';

  /// The one line description.
  @override
  String get description =>
      'Check that the Dart files are formatted, or format them with --fix.';

  /// Runs the format check.
  ///
  /// Returns whether it passed.
  @override
  Future<bool> runChecks() =>
      runFormat(loadPackageConfig(), fix: argResults?.flag('fix') ?? false);
}
