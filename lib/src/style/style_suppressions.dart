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

import 'package:inspectra/src/style/style_violation.dart';

/// The `// inspectra: ignore-style` comments of one file.
///
/// * `// inspectra: ignore-style no_else, no_comments` at the end of a line
///   suppresses those rules on that line; on a line of its own, on the next
///   line.
/// * `// inspectra: ignore-style-file public_docs` anywhere suppresses the
///   rule in the whole file.
///
/// Rules must be named; there is no way to suppress every rule at once.
final class StyleSuppressions {
  /// Creates the suppressions of a file from the rules suppressed in the
  /// whole file, [fileRules], and those suppressed per one-based line,
  /// [lineRules].
  const StyleSuppressions._(this.fileRules, this.lineRules);

  /// Reads the suppressions of the file [content].
  ///
  /// Returns the suppressions.
  factory StyleSuppressions.parse(String content) {
    final fileRules = <String>{};
    final lineRules = <int, Set<String>>{};
    final List<String> lines = content.replaceAll('\r\n', '\n').split('\n');
    for (var index = 0; index < lines.length; index++) {
      final String line = lines[index];
      final RegExpMatch? match = _comment.firstMatch(line);
      if (match == null) {
        continue;
      }
      final rules = <String>{
        for (final String rule in (match[2] ?? '').split(','))
          if (rule.trim().isNotEmpty) rule.trim(),
      };
      if (match[1] != null) {
        fileRules.addAll(rules);
        continue;
      }
      final bool ownLine = line.substring(0, match.start).trim().isEmpty;
      final int target = ownLine ? index + 2 : index + 1;
      lineRules.putIfAbsent(target, () => <String>{}).addAll(rules);
    }
    return StyleSuppressions._(fileRules, lineRules);
  }

  /// Matches an ignore comment and captures `-file` and the rule list.
  static final _comment = RegExp(
    r'//\s*inspectra:\s*ignore-style(-file)?\s+([a-z0-9_,\s]+)',
  );

  /// The rules suppressed in the whole file.
  final Set<String> fileRules;

  /// The rules suppressed on each one-based line.
  final Map<int, Set<String>> lineRules;

  /// Whether [violation] is suppressed.
  bool suppresses(StyleViolation violation) {
    final bool inFile = fileRules.contains(violation.ruleId);
    final bool onLine =
        lineRules[violation.line]?.contains(violation.ruleId) ?? false;
    return inFile || onLine;
  }
}
