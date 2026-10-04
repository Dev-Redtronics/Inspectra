import 'package:inspectra/src/api/api_command.dart';
import 'package:inspectra/src/cli/package_check_command.dart';

/// `inspectra api dump`: writes the public API of the package to its dump.
final class ApiDumpCommand extends PackageCheckCommand {
  /// Creates the command.
  ApiDumpCommand(super.context);

  /// The command name.
  @override
  String get name => 'dump';

  /// The one line description.
  @override
  String get description => 'Write the public API of the package to its dump.';

  /// Writes the dump.
  ///
  /// Returns `true`; writing the dump cannot fail a check.
  @override
  Future<bool> runChecks() async {
    final path = await dumpApi(loadPackageConfig(), packageRoot);
    out.writeln('Wrote the public API to $path.');
    return true;
  }
}
