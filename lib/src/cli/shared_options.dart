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

import 'package:args/args.dart';

import '../model/inspectra_exception.dart';
import '../model/severity.dart';
import '../report/output_format.dart';

/// The options shared by every command and their translation into
/// configuration overrides.
///
/// They are declared on each command rather than globally so that they can
/// follow the command name, exactly like `dart_audit audit --format json`.
final class SharedOptions {
  /// Prevents instantiation; this type only offers static helpers.
  const SharedOptions._();

  /// The accepted severity spellings.
  static final List<String> _severities = Severity.values
      .map((severity) => severity.name)
      .toList();

  /// Adds the shared options to [parser].
  static void addTo(ArgParser parser) {
    parser
      ..addOption(
        'config',
        help: 'Configuration file (default: inspectra.yaml if present).',
        valueHelp: 'path',
      )
      ..addMultiOption(
        'set',
        help: 'Override a configuration key, e.g. --set trivy.version=0.75.0',
        valueHelp: 'key=value',
      )
      ..addOption(
        'format',
        abbr: 'f',
        help: 'Output format.',
        allowed: OutputFormat.values.map((format) => format.id),
        defaultsTo: OutputFormat.text.id,
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Write the report to a file.',
        valueHelp: 'path',
      )
      ..addFlag(
        'color',
        defaultsTo: null,
        help: 'Force (--color) or disable (--no-color) ANSI colours.',
      )
      ..addFlag(
        'quiet',
        abbr: 'q',
        negatable: false,
        help: 'Only print warnings and errors.',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: 'Print diagnostics and list clean packages.',
      )
      ..addFlag(
        'offline',
        negatable: false,
        help: 'Never open a network connection.',
      )
      ..addOption(
        'fail-on',
        help: 'Minimum severity that makes the command exit with 1.',
        allowed: _severities,
      )
      ..addOption(
        'min-severity',
        help: 'Hide findings below this severity.',
        allowed: _severities,
      )
      ..addMultiOption(
        'ignore',
        abbr: 'i',
        help: 'Ignore a rule, advisory id or alias. Can be repeated.',
        valueHelp: 'ID',
      )
      ..addFlag(
        'exit-zero',
        negatable: false,
        help:
            'Exit with 0 even when findings reach the threshold. Never '
            'hides usage, input or availability errors.',
      );
  }

  /// Adds the Trivy options to [parser].
  static void addTrivyTo(ArgParser parser) {
    parser
      ..addOption(
        'trivy-mode',
        help: 'Whether Trivy runs.',
        allowed: <String>['auto', 'required', 'disabled'],
      )
      ..addOption(
        'trivy-version',
        help: 'Trivy version to download, or "latest".',
        valueHelp: 'version',
      )
      ..addFlag(
        'trivy-download',
        defaultsTo: null,
        help: 'Allow downloading Trivy when it is not installed.',
      )
      ..addFlag(
        'trivy-use-installed',
        defaultsTo: null,
        help: 'Use an installed Trivy even if its version differs.',
      )
      ..addOption(
        'trivy-executable',
        help: 'Path of the Trivy executable to use.',
        valueHelp: 'path',
      );
  }

  /// Translates the parsed [results] into configuration overrides keyed by
  /// dotted configuration path.
  ///
  /// Returns the overrides.
  ///
  /// Throws an [InvalidUsageException] for malformed `--set` values.
  static Map<String, String> overrides(ArgResults results) {
    final overrides = <String, String>{};
    for (final assignment in results['set'] as List<String>) {
      final separator = assignment.indexOf('=');
      if (separator <= 0) {
        throw InvalidUsageException(
          '--set expects key=value, got "$assignment".',
        );
      }
      final key = assignment.substring(0, separator).trim();
      overrides[key] = assignment.substring(separator + 1).trim();
    }
    final mapping = <String, String>{
      'fail-on': 'failOn',
      'min-severity': 'minSeverity',
      'trivy-mode': 'trivy.mode',
      'trivy-version': 'trivy.version',
      'trivy-executable': 'trivy.executable',
      'trivy-download': 'trivy.download',
      'trivy-use-installed': 'trivy.useInstalled',
    };
    for (final entry in mapping.entries) {
      final defined = results.options.contains(entry.key);
      final value = defined ? results[entry.key] : null;
      if (value != null) {
        overrides[entry.value] = '$value';
      }
    }
    if (results['offline'] == true) {
      overrides['network.offline'] = 'true';
    }
    return overrides;
  }
}
