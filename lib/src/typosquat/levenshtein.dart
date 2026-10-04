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

import 'dart:math';

/// Computes the Levenshtein edit distance between [a] and [b].
///
/// Insertions, deletions and substitutions each cost one. [limit] allows an
/// early exit: as soon as every value of a row exceeds it, `limit + 1` is
/// returned, which keeps comparisons against long lists of popular package
/// names cheap.
///
/// Returns the distance, or `limit + 1` when it exceeds [limit].
int levenshteinDistance(String a, String b, {int limit = 1 << 30}) {
  if ((a.length - b.length).abs() > limit) {
    return limit + 1;
  }
  var previous = List<int>.generate(b.length + 1, (index) => index);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;
    int rowMinimum = current[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      current[j] = min(
        min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] + cost,
      );
      rowMinimum = min(rowMinimum, current[j]);
    }
    if (rowMinimum > limit) {
      return limit + 1;
    }
    previous = current;
  }
  return previous[b.length];
}
