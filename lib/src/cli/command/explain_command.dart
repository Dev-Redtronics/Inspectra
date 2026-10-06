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

import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:inspectra/src/cli/command_context.dart';
import 'package:inspectra/src/cli/exit_code.dart';
import 'package:inspectra/src/config/config_suggestion.dart';
import 'package:inspectra/src/rules/rule_catalog.dart';
import 'package:inspectra/src/rules/rule_info.dart';

/// `inspectra explain [RULE_ID]`: explains a rule offline - what it
/// reports, why it matters and how to resolve it - or lists every rule.
final class ExplainCommand extends Command<int> {
  /// Creates the command with its `--format` option.
  ExplainCommand(this.context) {
    argParser.addOption(
      'format',
      abbr: 'f',
      help: 'Output format.',
      allowed: <String>['text', 'markdown', 'json'],
      defaultsTo: 'text',
    );
  }

  /// The outside world.
  final CommandContext context;

  /// Advisory ids of OSV.dev, which explain themselves online.
  static final _advisory = RegExp(
    '^(GHSA|CVE|PYSEC|OSV|GO|RUSTSEC|DART|PUB)-',
    caseSensitive: false,
  );

  /// The command name.
  @override
  String get name => 'explain';

  /// The one line description.
  @override
  String get description =>
      'Explain a rule: what it reports, why, and how to resolve it; '
      'without a rule id, list every rule.';

  /// The positional arguments.
  @override
  String get invocation => 'inspectra explain [RULE_ID] [options]';

  /// Prints the usage to standard output of the [context].
  @override
  void printUsage() => context.out.writeln(usage);

  /// Explains the rule, or lists every rule.
  ///
  /// Returns `0`, or `64` for an id that names no rule.
  @override
  Future<int> run() async {
    final String format = argResults?['format'] as String? ?? 'text';
    final String? id = argResults?.rest.firstOrNull;
    if (id == null) {
      context.out.write(_list(ruleCatalog(), format));
      return ExitCode.success.code;
    }
    final RuleInfo? rule = findRule(id);
    if (rule != null) {
      context.out.write(_explain(rule, format));
      return ExitCode.success.code;
    }
    if (_advisory.hasMatch(id)) {
      context.out.writeln(
        '$id is an advisory, reported by the OSV.dev audit or Trivy. Its '
        'details: https://osv.dev/vulnerability/${id.toUpperCase()}',
      );
      return ExitCode.success.code;
    }
    final known = <String>[for (final RuleInfo rule in ruleCatalog()) rule.id];
    context.err.writeln(
      'error: No rule $id.${didYouMean(id.toUpperCase(), known)} Lint '
      'codes are explained at https://dart.dev/tools/diagnostics and '
      'Trivy rules in its report; "inspectra explain" lists every rule.',
    );
    return ExitCode.usage.code;
  }

  /// Explains [rule] in [format].
  ///
  /// Returns the text, ending with a line break.
  static String _explain(RuleInfo rule, String format) {
    if (format == 'json') {
      return '${const JsonEncoder.withIndent('  ').convert(rule.toJson())}\n';
    }
    if (format == 'markdown') {
      return '## ${rule.id}\n\n'
          '**${rule.summary}** - source `${rule.source.id}`, severity '
          '${rule.severity.name}.\n\n${rule.explanation}\n';
    }
    return '${rule.id} (${rule.source.id}, ${rule.severity.name})\n'
        '${rule.summary}\n\n${rule.explanation}\n';
  }

  /// Lists [rules] in [format].
  ///
  /// Returns the text, ending with a line break.
  static String _list(List<RuleInfo> rules, String format) {
    if (format == 'json') {
      final entries = <Map<String, Object?>>[
        for (final rule in rules) rule.toJson(),
      ];
      return '${const JsonEncoder.withIndent('  ').convert(entries)}\n';
    }
    final out = StringBuffer();
    if (format == 'markdown') {
      out
        ..writeln('| Rule | Source | Severity | Reports |')
        ..writeln('|:--|:--|:--|:--|');
      for (final rule in rules) {
        out.writeln(
          '| `${rule.id}` | ${rule.source.id} | ${rule.severity.name} | '
          '${rule.summary} |',
        );
      }
      return out.toString();
    }
    for (final rule in rules) {
      out.writeln(
        '${rule.id.padRight(32)} ${rule.source.id.padRight(10)} '
        '${rule.severity.name.padRight(8)} ${rule.summary}',
      );
    }
    return out.toString();
  }
}
