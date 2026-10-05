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

/// The lines of one or more Dart files by what they hold.
///
/// Every line is counted once: as code when it holds code, also with a
/// trailing comment; as a comment when it holds only comments; and as blank
/// otherwise. [documentation] counts the comment lines that are
/// documentation comments.
final class LineCounts {
  /// Creates the counts.
  const LineCounts({
    this.total = 0,
    this.code = 0,
    this.comment = 0,
    this.documentation = 0,
    this.blank = 0,
    this.todos = 0,
  });

  /// Reads counts from their JSON [json]; missing numbers are `0`.
  ///
  /// Returns the counts.
  factory LineCounts.fromJson(Object? json) {
    int read(String key) {
      final Object? value = json is Map<String, Object?> ? json[key] : null;
      return value is int ? value : 0;
    }

    return LineCounts(
      total: read('total'),
      code: read('code'),
      comment: read('comment'),
      documentation: read('documentation'),
      blank: read('blank'),
      todos: read('todos'),
    );
  }

  /// All lines.
  final int total;

  /// The lines with code, the lines of code without comments.
  final int code;

  /// The lines with nothing but comments.
  final int comment;

  /// The comment lines that are documentation comments, `///` or `/**`.
  final int documentation;

  /// The empty lines and the lines with only whitespace.
  final int blank;

  /// The `TODO`, `FIXME`, `HACK` and `XXX` markers in comments.
  final int todos;

  /// The lines of code with their comments: all but the blank lines.
  int get withComments => code + comment;

  /// The share of comment lines among the lines with code or comments,
  /// from 0 to 1.
  double get commentRatio => withComments == 0 ? 0 : comment / withComments;

  /// Returns the sum of these counts and [other].
  LineCounts operator +(LineCounts other) => LineCounts(
    total: total + other.total,
    code: code + other.code,
    comment: comment + other.comment,
    documentation: documentation + other.documentation,
    blank: blank + other.blank,
    todos: todos + other.todos,
  );

  /// Serializes the counts.
  ///
  /// Returns the JSON object.
  Map<String, Object?> toJson() => <String, Object?>{
    'total': total,
    'code': code,
    'comment': comment,
    'documentation': documentation,
    'blank': blank,
    'todos': todos,
  };
}
