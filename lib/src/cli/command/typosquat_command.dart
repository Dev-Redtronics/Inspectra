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

import 'dart:io';

import 'package:args/args.dart';

import '../../model/finding.dart';
import '../../model/severity.dart';
import '../../pub/dependency_spec.dart';
import '../../pub/pubspec_key_locator.dart';
import '../../pub/pubspec_parser.dart';
import '../../report/command_report.dart';
import '../../typosquat/typosquat_report.dart';
import '../command_session.dart';
import '../inspectra_command.dart';

/// `inspectra typosquat`: checks the dependencies of a `pubspec.yaml` for
/// typosquatting and dependency confusion.
final class TyposquatCommand extends InspectraCommand {
  /// Creates the command.
  TyposquatCommand(super.context) {
    argParser.addOption(
      'pubspec',
      help: 'Path to pubspec.yaml.',
      defaultsTo: 'pubspec.yaml',
    );
  }

  /// The command name.
  @override
  String get name => 'typosquat';

  /// The one line description.
  @override
  String get description =>
      'Scan pubspec.yaml for typosquatting and dependency confusion risks.';

  /// HIGH or worse fails the command, as in `dart_audit`.
  @override
  Severity get defaultFailOn => Severity.high;

  /// Analyses the pubspec.
  ///
  /// Returns the typosquat report.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    final path = session.resolve(results['pubspec'] as String);
    final display = session.display(path);
    final pubspec = const PubspecParser().parseFile(path);
    final lines = File(path).readAsLinesSync();
    final names = pubspec.declaredNames;
    session.console.info(
      'Analyzing ${names.length} dependencies for '
      'typosquatting and confusion...',
    );
    final findings = <Finding>[
      ...session.typosquatDetector().analyze(
        names,
        locate: (name) => locatePubspecKey(lines, name, display),
      ),
    ];
    final confusion = session.confusionDetector();
    if (confusion != null) {
      findings.addAll(
        await confusion.analyze(<String, DependencySpec>{
          ...pubspec.dependencies,
          ...pubspec.devDependencies,
        }, locate: (name) => locatePubspecKey(lines, name, display)),
      );
    }
    final outcome = session.filter().apply(findings);
    return TyposquatReport(
      pubspecPath: display,
      packages: names,
      findings: outcome.kept,
      confusionChecked: confusion != null,
    );
  }
}
