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

import 'package:inspectra/src/util/levenshtein.dart';

/// Finds the candidate closest to the unknown [name], for a "did you mean"
/// hint: within an edit distance of a third of its length, at least two.
///
/// Returns the closest of [candidates], or `null` when none is close.
String? closestName(String name, Iterable<String> candidates) {
  final int limit = name.length ~/ 3 < 2 ? 2 : name.length ~/ 3;
  String? best;
  int bestDistance = limit + 1;
  for (final candidate in candidates) {
    final int distance = levenshteinDistance(name, candidate, limit: limit);
    if (distance < bestDistance && candidate != name) {
      best = candidate;
      bestDistance = distance;
    }
  }
  return best;
}

/// Returns the hint for the unknown [name] among [candidates], such as
/// ` Did you mean "secret"?`, or an empty text when none is close.
String didYouMean(String name, Iterable<String> candidates) {
  final String? closest = closestName(name, candidates);
  return closest == null ? '' : ' Did you mean "$closest"?';
}
