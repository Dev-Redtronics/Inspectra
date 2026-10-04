import 'package:inspectra/src/cli/package_check_command.dart';

/// `inspectra api check`: fails when the public API differs from its
/// committed dump.
final class ApiCheckCommand extends PackageCheckCommand {
  /// Creates the command.
  ApiCheckCommand(super.context);

  /// The command name.
  @override
  String get name => 'check';

  /// The one line description.
  @override
  String get description =>
      'Fail when the public API differs from its committed dump.';

  /// Runs the API check.
  ///
  /// Returns whether it passed.
  @override
  Future<bool> runChecks() => runApiCheck(loadPackageConfig());
}
