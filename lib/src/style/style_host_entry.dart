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
import 'dart:io';

import 'package:inspectra/src/style/built_in_style_rules.dart';
import 'package:inspectra/src/style/style_checker.dart';
import 'package:inspectra/src/style/style_rule.dart';
import 'package:inspectra/src/style/style_violation.dart';
import 'package:path/path.dart' as p;

/// Runs the custom [rules] of a package for Inspectra.
///
/// Inspectra generates a small program that imports the package's custom
/// rule files and calls this function; it is not meant to be called by
/// hand. [arguments] holds the path of the request Inspectra wrote: the
/// package root, the files to check relative to it, the ids of the rules
/// that are switched off, and where to write the answer. The answer lists
/// every rule with its description and the violations of the rules that
/// are on, or the reason why the rules cannot run.
///
/// Throws a [FileSystemException] when the request cannot be read.
Future<void> runStyleHost(List<String> arguments, List<StyleRule> rules) async {
  final request = jsonDecode(
    await File(arguments.single).readAsString(),
  ) as Map<String, Object?>;
  final output = File(request['output']! as String);
  final String? error = _validate(rules);
  if (error != null) {
    await output.writeAsString(jsonEncode(<String, Object?>{'error': error}));
    return;
  }
  final disabled = <String>{
    for (final Object? id in request['disabled']! as List<Object?>) '$id',
  };
  final checker = StyleChecker(<StyleRule>[
    for (final rule in rules)
      if (!disabled.contains(rule.id)) rule,
  ]);
  final violations = <StyleViolation>[];
  final root = request['root']! as String;
  for (final path in request['files']! as List<Object?>) {
    final String content = await File(p.join(root, '$path')).readAsString();
    violations.addAll(checker.checkSource('$path', content));
  }
  await output.writeAsString(
    jsonEncode(<String, Object?>{
      'rules': <Map<String, Object?>>[
        for (final rule in rules)
          <String, Object?>{'id': rule.id, 'description': rule.description},
      ],
      'violations': <Map<String, Object?>>[
        for (final violation in violations) violation.toJson(),
      ],
    }),
  );
}

/// Checks that the ids of [rules] are valid, unique and not built in.
///
/// Returns the first problem, or `null` when there is none.
String? _validate(List<StyleRule> rules) {
  final seen = <String>{};
  for (final rule in rules) {
    final String id = rule.id;
    if (!styleRuleIdPattern.hasMatch(id)) {
      return 'The custom style rule id "$id" is not lower snake case, such '
          'as no_print.';
    }
    if (builtInStyleRuleIds.contains(id)) {
      return 'The custom style rule id "$id" is the id of a built-in rule.';
    }
    if (!seen.add(id)) {
      return 'The custom style rule id "$id" is used more than once.';
    }
  }
  return null;
}
