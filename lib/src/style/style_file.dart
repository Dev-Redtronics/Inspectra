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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as p;

/// A parsed Dart file that style rules inspect.
///
/// The file is parsed without resolution: rules see the syntax tree, not
/// types, which keeps the check fast and independent of `dart pub get`.
final class StyleFile {
  /// Creates the file at [path], relative to the package root with `/` as
  /// separator, whose text [content] parses to [unit].
  const StyleFile({
    required this.path,
    required this.content,
    required this.unit,
    required this.lineInfo,
  });

  /// The path relative to the package root, with `/` as separator.
  final String path;

  /// The text of the file.
  final String content;

  /// The syntax tree of the file.
  final CompilationUnit unit;

  /// Maps offsets in [content] to lines and columns.
  final LineInfo lineInfo;

  /// The file name without directory and `.dart` extension, such as
  /// `user_repository`.
  String get name => p.posix.basenameWithoutExtension(path);

  /// Whether the file is a `part of` another library.
  bool get isPart => unit.directives.any((d) => d is PartOfDirective);
}
