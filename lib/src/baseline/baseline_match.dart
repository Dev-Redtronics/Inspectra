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

/// The result of matching findings against a baseline.
final class BaselineMatch<T> {
  /// Creates a match.
  const BaselineMatch({
    required this.kept,
    required this.baselined,
    required this.stale,
  });

  /// The findings that remain reported, in their original order.
  final List<T> kept;

  /// The findings the baseline covers, in their original order.
  final List<T> baselined;

  /// How many recorded findings of the checked part of the baseline no
  /// longer occur.
  final int stale;
}
