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

import 'package:inspectra/src/model/severity.dart';

/// One pattern based detection rule of the source inspector.
final class RegexRule {
  /// Creates a rule.
  ///
  /// [id] is the stable rule identifier, [pattern] the case-insensitive
  /// regular expression, [severity] the severity of a match and
  /// [description] the explanation shown to the user. With [wholeFile] the
  /// pattern is matched against the complete file so it can span lines;
  /// otherwise it is matched line by line. [extensions] limits the rule to
  /// files with these extensions. [checksHost] marks the URL rule whose
  /// matches are additionally checked against the trusted host list.
  RegexRule({
    required this.id,
    required String pattern,
    required this.severity,
    required this.description,
    required this.extensions,
    this.wholeFile = false,
    this.checksHost = false,
  }) : pattern = RegExp(pattern, caseSensitive: false);

  /// The stable rule identifier.
  final String id;

  /// The compiled, case-insensitive pattern.
  final RegExp pattern;

  /// The severity of a match.
  final Severity severity;

  /// The explanation shown to the user.
  final String description;

  /// The file extensions, including the dot, this rule applies to.
  final Set<String> extensions;

  /// Whether the pattern is matched against the whole file.
  final bool wholeFile;

  /// Whether matches are URLs whose host must be checked.
  final bool checksHost;
}
