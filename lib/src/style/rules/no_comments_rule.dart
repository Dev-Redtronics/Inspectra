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

import 'package:analyzer/dart/ast/token.dart';
import 'package:inspectra/src/style/license_header.dart';
import 'package:inspectra/src/style/style_file.dart';
import 'package:inspectra/src/style/style_reporter.dart';
import 'package:inspectra/src/style/style_rule.dart';

/// `no_comments`: no comments except `///` documentation and the license
/// header. Code says what it does through names; a comment that is needed
/// is documentation of a declaration.
///
/// Ignore comments such as `// ignore:` or `// inspectra: ignore-style` are
/// comments too, so this rule leaves exceptions to `exclude` globs.
final class NoCommentsRule extends StyleRule {
  /// Creates the rule; comments inside [header] are allowed. Without a
  /// header, a block comment that starts the file is taken for one.
  const NoCommentsRule({this.header});

  /// The license header, or `null` when none is configured.
  final LicenseHeader? header;

  /// The rule id.
  @override
  String get id => 'no_comments';

  /// What the rule requires.
  @override
  String get description =>
      'No comments except /// documentation and the license header.';

  /// Reports every other comment.
  @override
  void check(StyleFile file, StyleReporter reporter) {
    final int headerEnd = header?.matchLength(file.content) ?? 0;
    Token? token = file.unit.beginToken;
    while (token != null) {
      Token? comment = token.precedingComments;
      while (comment != null) {
        if (!_allowed(comment, headerEnd)) {
          reporter.reportAt(
            comment,
            'No comments: only /// documentation is allowed.',
          );
        }
        comment = comment.next;
      }
      if (token.isEof) {
        return;
      }
      token = token.next;
    }
  }

  /// Whether [comment] is documentation or part of the license header
  /// ending at [headerEnd].
  bool _allowed(Token comment, int headerEnd) {
    final String lexeme = comment.lexeme;
    final bool documentation = lexeme.startsWith('///');
    final bool inHeader = comment.end <= headerEnd;
    final bool leadingBlock =
        header == null && comment.offset == 0 && lexeme.startsWith('/*');
    return documentation || inHeader || leadingBlock;
  }
}
