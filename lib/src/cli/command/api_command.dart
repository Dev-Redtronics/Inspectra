import 'package:args/command_runner.dart';
import 'package:inspectra/src/cli/command/api_check_command.dart';
import 'package:inspectra/src/cli/command/api_dump_command.dart';
import 'package:inspectra/src/cli/command_context.dart';

/// `inspectra api`: records or checks the public API dump.
final class ApiCommand extends Command<int> {
  /// Creates the command with its `dump` and `check` subcommands.
  ApiCommand(this.context) {
    addSubcommand(ApiDumpCommand(context));
    addSubcommand(ApiCheckCommand(context));
  }

  /// The outside world.
  final CommandContext context;

  /// The command name.
  @override
  String get name => 'api';

  /// The one line description.
  @override
  String get description => 'Record or check the public API dump.';

  /// Prints the usage to standard output of the [context].
  @override
  void printUsage() => context.out.writeln(usage);
}
