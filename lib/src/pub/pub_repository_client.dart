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

import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/net/http_result.dart';
import 'package:inspectra/src/net/http_transport.dart';
import 'package:inspectra/src/pub/package_name.dart';
import 'package:inspectra/src/pub/pub_package.dart';
import 'package:inspectra/src/pub/pub_package_options.dart';
import 'package:inspectra/src/pub/pub_score.dart';
import 'package:inspectra/src/pub/pub_version.dart';

/// A client of the pub repository API, pub.dev by default.
///
/// It uses the documented endpoints:
///
/// * `GET /api/packages/<name>` for versions, publication dates and archives;
/// * `GET /api/packages/<name>/score` for points, likes and downloads;
/// * `GET /api/packages/<name>/publisher` for the verified publisher;
/// * `GET /api/packages/<name>/options` for discontinuation.
///
/// Private repositories frequently do not implement the last three; a `404`
/// there is reported as missing data rather than as a failure.
final class PubRepositoryClient {
  /// Creates a client for the repository at [baseUrl].
  const PubRepositoryClient({required this.transport, required this.baseUrl});

  /// The HTTP transport.
  final HttpTransport transport;

  /// The repository base URL without trailing slash.
  final String baseUrl;

  /// The media type of version 2 of the pub repository API.
  static const _acceptHeader = <String, String>{
    'accept': 'application/vnd.pub.v2+json',
  };

  /// The display name of the repository used in messages.
  String get _service => Uri.parse(baseUrl).host;

  /// Fetches the version listing of [name].
  ///
  /// Returns the listing, or `null` when the package does not exist.
  ///
  /// Throws an [UnavailableException] when the repository cannot be queried.
  Future<PubPackage?> package(String name) async {
    final HttpResult? result = await _get(name, '');
    if (result == null) {
      return null;
    }
    final Map<String, Object?> json = result.jsonObject(_service);
    final Object? latest = json['latest'];
    final latestVersion = latest is Map<String, Object?>
        ? '${latest['version'] ?? ''}'
        : '';
    final Object? versions = json['versions'];
    final List<PubVersion> parsedVersions = versions is List<Object?>
        ? versions.whereType<Map<String, Object?>>().map(_version).toList()
        : const <PubVersion>[];
    return PubPackage(
      name: name,
      latestVersion: latestVersion,
      versions: parsedVersions,
    );
  }

  /// Fetches the score of [name].
  ///
  /// Returns the score, or `null` when the repository does not offer one.
  ///
  /// Throws an [UnavailableException] when the repository cannot be queried.
  Future<PubScore?> score(String name) async {
    final HttpResult? result = await _get(name, '/score');
    if (result == null) {
      return null;
    }
    final Map<String, Object?> json = result.jsonObject(_service);
    return PubScore(
      grantedPoints: _int(json['grantedPoints']),
      maxPoints: _int(json['maxPoints']),
      likeCount: _int(json['likeCount']),
      downloadCount30Days: _int(json['downloadCount30Days']),
    );
  }

  /// Fetches the verified publisher of [name].
  ///
  /// Returns the publisher id, or `null` when the package has none.
  ///
  /// Throws an [UnavailableException] when the repository cannot be queried.
  Future<String?> publisher(String name) async {
    final HttpResult? result = await _get(name, '/publisher');
    if (result == null) {
      return null;
    }
    final Object? id = result.jsonObject(_service)['publisherId'];
    return id is String && id.isNotEmpty ? id : null;
  }

  /// Fetches the status flags of [name].
  ///
  /// Returns the flags; all `false` when the repository does not offer them.
  ///
  /// Throws an [UnavailableException] when the repository cannot be queried.
  Future<PubPackageOptions> options(String name) async {
    final HttpResult? result = await _get(name, '/options');
    if (result == null) {
      return const PubPackageOptions();
    }
    final Map<String, Object?> json = result.jsonObject(_service);
    final Object? replacedBy = json['replacedBy'];
    return PubPackageOptions(
      isDiscontinued: json['isDiscontinued'] == true,
      isUnlisted: json['isUnlisted'] == true,
      replacedBy: replacedBy is String ? replacedBy : null,
    );
  }

  /// Performs a `GET` of `/api/packages/<name><suffix>`.
  ///
  /// Returns the successful response, or `null` for `404`.
  ///
  /// Throws an [UnavailableException] for any other non-success status.
  Future<HttpResult?> _get(String name, String suffix) async {
    final String validName = PackageName.validate(name);
    final Uri uri = Uri.parse('$baseUrl/api/packages/$validName$suffix');
    final HttpResult result = await transport.get(uri, headers: _acceptHeader);
    if (result.isNotFound) {
      return null;
    }
    if (!result.isSuccess) {
      throw UnavailableException(
        '$_service returned HTTP ${result.statusCode} for $uri.',
      );
    }
    return result;
  }

  /// Parses one entry of the `versions` list.
  ///
  /// Returns the version record.
  PubVersion _version(Map<String, Object?> json) {
    final Object? published = json['published'];
    final Object? sha = json['archive_sha256'];
    final Object? url = json['archive_url'];
    return PubVersion(
      version: '${json['version'] ?? ''}',
      published: published is String ? DateTime.tryParse(published) : null,
      retracted: json['retracted'] == true,
      archiveUrl: url is String ? url : null,
      archiveSha256: sha is String ? sha : null,
    );
  }

  /// Returns [value] as an integer, or `null` when it is not a number.
  int? _int(Object? value) => value is num ? value.toInt() : null;
}
