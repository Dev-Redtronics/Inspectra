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

/// One published version of a package on a pub repository.
final class PubVersion {
  /// Creates a version record.
  const PubVersion({
    required this.version,
    this.published,
    this.retracted = false,
    this.archiveUrl,
    this.archiveSha256,
  });

  /// The version string.
  final String version;

  /// When the version was published, if reported.
  final DateTime? published;

  /// Whether the publisher retracted this version.
  final bool retracted;

  /// Where the `.tar.gz` archive of this version can be downloaded.
  final String? archiveUrl;

  /// The SHA-256 checksum of the archive, as published by the repository.
  final String? archiveSha256;
}
