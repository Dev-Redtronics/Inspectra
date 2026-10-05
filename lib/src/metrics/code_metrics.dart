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

import 'package:inspectra/src/metrics/line_counts.dart';

/// The lines of the Dart files of a project, file by file.
final class CodeMetrics {
  /// Creates the metrics of the hand-written [files] and the [generated]
  /// ones, each with its path relative to the project.
  const CodeMetrics({
    required this.files,
    this.generated = const <(String, LineCounts)>[],
  });

  /// The hand-written Dart files and their lines.
  final List<(String, LineCounts)> files;

  /// The generated Dart files, such as `*.g.dart`, and their lines; they
  /// are not part of [total].
  final List<(String, LineCounts)> generated;

  /// The lines of all hand-written files.
  LineCounts get total =>
      files.fold(const LineCounts(), (sum, file) => sum + file.$2);

  /// The lines of all generated files.
  LineCounts get generatedTotal =>
      generated.fold(const LineCounts(), (sum, file) => sum + file.$2);

  /// The files grouped by their top-level directory, such as `lib` or
  /// `test`, with the number of files; files in the project root form the
  /// area `.`. The area with the most code comes first.
  List<(String, int, LineCounts)> get areas {
    final counts = <String, LineCounts>{};
    final sizes = <String, int>{};
    for (final (String path, LineCounts lines) in files) {
      final int slash = path.indexOf('/');
      final String area = slash < 0 ? '.' : path.substring(0, slash);
      counts[area] = (counts[area] ?? const LineCounts()) + lines;
      sizes[area] = (sizes[area] ?? 0) + 1;
    }
    return <(String, int, LineCounts)>[
      for (final MapEntry<String, LineCounts> entry in counts.entries)
        (entry.key, sizes[entry.key] ?? 0, entry.value),
    ]..sort((a, b) {
      final int byCode = b.$3.code.compareTo(a.$3.code);
      return byCode != 0 ? byCode : a.$1.compareTo(b.$1);
    });
  }

  /// Returns the [count] files with the most lines of code, the largest
  /// first.
  List<(String, LineCounts)> largest(int count) =>
      (<(String, LineCounts)>[...files]..sort((a, b) {
            final int byCode = b.$2.code.compareTo(a.$2.code);
            return byCode != 0 ? byCode : a.$1.compareTo(b.$1);
          }))
          .take(count)
          .toList();
}
