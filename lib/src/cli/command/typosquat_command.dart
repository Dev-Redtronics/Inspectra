/*
 * Copyright 2026 Davils
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
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/inspectra_command.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/policy/filter_outcome.dart';
import 'package:inspectra/src/pub/dependency_spec.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/pub/pubspec_key_locator.dart';
import 'package:inspectra/src/pub/pubspec_parser.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/typosquat/confusion_detector.dart';
import 'package:inspectra/src/typosquat/typosquat_report.dart';

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
    final String path = session.resolve(results['pubspec'] as String);
    final String display = session.display(path);
    final Pubspec pubspec = const PubspecParser().parseFile(path);
    final List<String> lines = File(path).readAsLinesSync();
    final List<String> names = pubspec.declaredNames;
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
    final ConfusionDetector? confusion = session.confusionDetector();
    if (confusion != null) {
      findings.addAll(
        await confusion.analyze(<String, DependencySpec>{
          ...pubspec.dependencies,
          ...pubspec.devDependencies,
        }, locate: (name) => locatePubspecKey(lines, name, display)),
      );
    }
    final FilterOutcome outcome = session.filter().apply(findings);
    return TyposquatReport(
      pubspecPath: display,
      packages: names,
      findings: outcome.kept,
      confusionChecked: confusion != null,
    );
  }
}
