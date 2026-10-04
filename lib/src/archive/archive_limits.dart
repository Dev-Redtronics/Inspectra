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

/// Upper bounds that protect against decompression bombs.
final class ArchiveLimits {
  /// Creates limits for archives of at most [maxArchiveBytes] compressed
  /// bytes, [maxExtractedBytes] uncompressed bytes and [maxEntries] entries.
  const ArchiveLimits({
    required this.maxArchiveBytes,
    required this.maxExtractedBytes,
    required this.maxEntries,
  });

  /// The maximum compressed archive size in bytes.
  final int maxArchiveBytes;

  /// The maximum total uncompressed size in bytes.
  final int maxExtractedBytes;

  /// The maximum number of entries.
  final int maxEntries;
}
