import 'dart:io';

import 'package:inspectra/src/cli/inspectra_command_runner.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await InspectraCommandRunner().run(arguments);
}
