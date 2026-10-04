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

/// The license header every Dart file must start with, read from a
/// template file of the package.
///
/// The template is compared line by line after normalising line endings
/// and trailing white space. `{year}` matches a four digit year or a range
/// such as `2020-2026`. A file may start with a `#!` line and a byte order
/// mark before the header.
final class LicenseHeader {
  /// Creates a header from the [template] read from [source], the path of
  /// the template relative to the package root.
  LicenseHeader(String template, {required this.source})
    : _pattern = _compile(template);

  /// The template file, relative to the package root.
  final String source;

  /// Matches the header at the start of a file.
  final RegExp _pattern;

  /// Matches a four digit year or a year range.
  static const _year = r'\d{4}(?:\s*[-–]\s*\d{4})?';

  /// Compiles [template] into a pattern anchored at the start of a file.
  ///
  /// Returns the pattern.
  static RegExp _compile(String template) {
    final List<String> lines = _lines(template);
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    final String body = lines
        .map((line) => line.split('{year}').map(RegExp.escape).join(_year))
        .join(r'[ \t]*\r?\n');
    return RegExp('^(?:﻿)?(?:#![^\n]*\n)?$body[ \t]*(?:\r?\n|\$)');
  }

  /// Splits [text] into lines without trailing white space.
  ///
  /// Returns the lines.
  static List<String> _lines(String text) => text
      .replaceAll('\r\n', '\n')
      .split('\n')
      .map((line) => line.trimRight())
      .toList();

  /// Returns the length of the header at the start of [content], or `null`
  /// when [content] does not start with it.
  int? matchLength(String content) => _pattern.matchAsPrefix(content)?.end;
}
