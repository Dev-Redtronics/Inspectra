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

import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/config/style_config.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/style/built_in_style_rules.dart';
import 'package:inspectra/src/style/license_header.dart';
import 'package:inspectra/src/style/style_checker.dart';
import 'package:inspectra/src/style/style_host.dart';
import 'package:inspectra/src/style/style_host_answer.dart';
import 'package:inspectra/src/style/style_result.dart';
import 'package:inspectra/src/style/style_rule.dart';
import 'package:inspectra/src/style/style_violation.dart';
import 'package:path/path.dart' as p;

/// Checks [files], relative to [packageRoot], against the style rules
/// selected by [config]: the built-in rules in-process and the custom rules
/// of `custom_rules` in a program of their own, see [StyleHost].
///
/// [read] returns the text of a file of the package, or `null` when it does
/// not exist; it reads from [packageRoot] by default, and the builder reads
/// through build_runner. The custom rules always read from disk.
///
/// Returns the result.
///
/// Throws an [InvalidInputException] when the license header template or
/// a custom rule file is missing or the custom rules cannot run, an
/// [InspectraConfigException] when `rules` names a rule that exists
/// neither built in nor custom, and an [UnavailableException] when `dart`
/// cannot be started for the custom rules.
Future<StyleResult> checkStyle({
  required StyleConfig config,
  required String packageRoot,
  required List<String> files,
  Future<String?> Function(String path)? read,
}) async {
  final Future<String?> Function(String path) reader =
      read ?? (path) => _readFile(packageRoot, path);
  final LicenseHeader? header = await _header(config, reader);
  final builtIns = <StyleRule>[
    for (final rule in builtInStyleRules(header: header))
      if (config.runs(rule.id)) rule,
  ];
  final checker = StyleChecker(builtIns);
  final violations = <StyleViolation>[];
  for (final path in files) {
    final String? content = await reader(path);
    if (content == null) {
      throw InvalidInputException('The file $path cannot be read.');
    }
    violations.addAll(checker.checkSource(path, content));
  }
  final List<String> custom = await _runCustomRules(
    config,
    packageRoot,
    files,
    violations,
  );
  final known = <String>{...builtInStyleRuleIds, ...custom};
  for (final String id in config.rules.keys) {
    if (!known.contains(id)) {
      throw InspectraConfigException(
        'style.rules.$id',
        'unknown rule. Known rules: ${known.join(', ')}.',
      );
    }
  }
  return StyleResult(
    checked: files.length,
    rules: <String>[
      for (final rule in builtIns) rule.id,
      for (final id in custom)
        if (config.runs(id)) id,
    ],
    violations: violations..sort(compareStyleViolations),
    failOnFindings: config.failOnFindings,
  );
}

/// Runs the custom rules of [config] on [files] and adds their violations
/// to [violations].
///
/// Returns the ids of every custom rule, also those switched off.
Future<List<String>> _runCustomRules(
  StyleConfig config,
  String packageRoot,
  List<String> files,
  List<StyleViolation> violations,
) async {
  if (config.customRules.isEmpty) {
    return const <String>[];
  }
  final StyleHostAnswer answer = await StyleHost(packageRoot).run(
    ruleFiles: config.customRules,
    files: files,
    disabled: <String>{
      for (final MapEntry<String, bool> rule in config.rules.entries)
        if (!rule.value) rule.key,
    },
  );
  violations.addAll(answer.violations);
  return answer.rules.keys.toList();
}

/// Reads the license header template of [config] with [read].
///
/// Returns the header, or `null` when none is configured.
///
/// Throws an [InvalidInputException] when the template does not exist.
Future<LicenseHeader?> _header(
  StyleConfig config,
  Future<String?> Function(String path) read,
) async {
  final String? source = config.licenseHeader;
  if (source == null) {
    return null;
  }
  final String? template = await read(source);
  if (template == null) {
    throw InvalidInputException(
      'The license header template $source (style.license_header) does not '
      'exist.',
    );
  }
  return LicenseHeader(template, source: source);
}

/// Reads the file at [path] below [packageRoot].
///
/// Returns its text, or `null` when it does not exist.
Future<String?> _readFile(String packageRoot, String path) async {
  final file = File(p.join(packageRoot, path));
  if (!file.existsSync()) {
    return null;
  }
  return file.readAsString();
}
