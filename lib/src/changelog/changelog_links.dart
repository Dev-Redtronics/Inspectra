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

/// Builds the commit and comparison links of a changelog from URL
/// templates.
final class ChangelogLinks {
  /// Creates the links into [repository], an `https://` or `http://` URL
  /// without trailing slash, using the [commitUrl] and [compareUrl]
  /// templates.
  const ChangelogLinks({
    required this.repository,
    required this.commitUrl,
    required this.compareUrl,
  });

  /// The repository URL.
  final String repository;

  /// The commit link with the placeholders `{repository}` and `{hash}`.
  final String commitUrl;

  /// The comparison link with the placeholders `{repository}`, `{from}`
  /// and `{to}`.
  final String compareUrl;

  /// Normalises a repository URL as written in `pubspec.yaml` or the
  /// configuration: surrounding white space, a trailing slash and a
  /// trailing `.git` are removed.
  ///
  /// Returns the URL, or `null` when [url] is absent or not an `https://`
  /// or `http://` URL, so that no link can point elsewhere.
  static String? normalizeRepository(String? url) {
    final String text = url?.trim() ?? '';
    final Uri? uri = Uri.tryParse(text);
    final bool web =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    if (!web) {
      return null;
    }
    var normalized = text;
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.endsWith('.git')) {
      normalized = normalized.substring(0, normalized.length - 4);
    }
    return normalized;
  }

  /// Returns the link to the commit [hash].
  String commit(String hash) => commitUrl
      .replaceAll('{repository}', repository)
      .replaceAll('{hash}', Uri.encodeComponent(hash));

  /// Returns the link comparing the tags [from] and [to].
  String compare(String from, String to) => compareUrl
      .replaceAll('{repository}', repository)
      .replaceAll('{from}', Uri.encodeComponent(from))
      .replaceAll('{to}', Uri.encodeComponent(to));
}
