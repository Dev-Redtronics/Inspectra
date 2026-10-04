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

import '../model/inspectra_exception.dart';
import '../net/http_transport.dart';
import '../pub/locked_package.dart';
import '../util/bounded_concurrency.dart';
import 'osv_cache.dart';
import 'osv_vulnerability.dart';

/// Queries OSV.dev for vulnerabilities of Dart packages.
///
/// The client performs the two step protocol that OSV.dev requires:
///
/// 1. `POST /v1/querybatch` in batches, following `next_page_token` until
///    every result page has been read. The answer only contains the id and
///    modification time of each advisory.
/// 2. `GET /v1/vulns/{id}` for every distinct advisory, concurrently but
///    bounded, served from [cache] whenever possible.
final class OsvClient {
  /// Creates a client for the OSV compatible API at [baseUrl].
  const OsvClient({
    required this.transport,
    required this.baseUrl,
    required this.cache,
  });

  /// The number of queries per `querybatch` request; OSV.dev accepts up to
  /// 1000.
  static const int batchSize = 500;

  /// The OSV ecosystem name of Dart packages.
  static const String ecosystem = 'Pub';

  /// The HTTP transport.
  final HttpTransport transport;

  /// The API base URL without trailing slash.
  final String baseUrl;

  /// The record cache.
  final OsvCache cache;

  /// Queries the advisories affecting [packages].
  ///
  /// [onProgress] is called after each batch with the number of processed
  /// and total packages.
  ///
  /// Returns the full advisories per package; packages without advisories
  /// map to an empty list.
  ///
  /// Throws an [UnavailableException] when OSV.dev cannot be queried.
  Future<Map<LockedPackage, List<OsvVulnerability>>> query(
    List<LockedPackage> packages, {
    void Function(int done, int total)? onProgress,
  }) async {
    final references = <LockedPackage, Map<String, String>>{};
    for (var start = 0; start < packages.length; start += batchSize) {
      final end = start + batchSize > packages.length
          ? packages.length
          : start + batchSize;
      final batch = packages.sublist(start, end);
      references.addAll(await _queryBatch(batch));
      onProgress?.call(end, packages.length);
    }
    final ids = <String, String>{for (final refs in references.values) ...refs};
    final records = await _fetchAll(ids);
    return <LockedPackage, List<OsvVulnerability>>{
      for (final entry in references.entries)
        entry.key: <OsvVulnerability>[
          for (final id in entry.value.keys) ?records[id],
        ],
    };
  }

  /// Runs `querybatch` for [batch], following pagination tokens.
  ///
  /// Returns the advisory ids and modification times per package.
  Future<Map<LockedPackage, Map<String, String>>> _queryBatch(
    List<LockedPackage> batch,
  ) async {
    final found = <LockedPackage, Map<String, String>>{
      for (final package in batch) package: <String, String>{},
    };
    var pending = <(LockedPackage, String?)>[
      for (final package in batch) (package, null),
    ];
    while (pending.isNotEmpty) {
      final results = await _post(pending);
      final next = <(LockedPackage, String?)>[];
      for (var index = 0; index < pending.length; index++) {
        final package = pending[index].$1;
        final result = index < results.length ? results[index] : null;
        final token = _collect(result, found[package]!);
        if (token != null) {
          next.add((package, token));
        }
      }
      pending = next;
    }
    return found;
  }

  /// Sends one `querybatch` request for [queries].
  ///
  /// Returns the `results` list.
  ///
  /// Throws an [UnavailableException] for non-success responses.
  Future<List<Object?>> _post(List<(LockedPackage, String?)> queries) async {
    final uri = Uri.parse('$baseUrl/v1/querybatch');
    final body = <String, Object?>{
      'queries': <Map<String, Object?>>[
        for (final (package, token) in queries)
          <String, Object?>{
            'package': <String, Object?>{
              'name': package.name,
              'ecosystem': ecosystem,
            },
            'version': package.version,
            'page_token': ?token,
          },
      ],
    };
    final result = await transport.postJson(uri, body);
    if (!result.isSuccess) {
      throw UnavailableException(
        'OSV.dev returned HTTP ${result.statusCode} for $uri.',
      );
    }
    final results = result.jsonObject('OSV.dev')['results'];
    return results is List<Object?> ? results : const <Object?>[];
  }

  /// Copies the advisory references of one batch [result] into [target].
  ///
  /// Returns the `next_page_token`, or `null` when the result is complete.
  String? _collect(Object? result, Map<String, String> target) {
    if (result is! Map<String, Object?>) {
      return null;
    }
    final vulns = result['vulns'];
    final entries = vulns is List<Object?> ? vulns : const <Object?>[];
    for (final entry in entries.whereType<Map<String, Object?>>()) {
      final id = entry['id'];
      if (id is String) {
        target[id] = '${entry['modified'] ?? ''}';
      }
    }
    final token = result['next_page_token'];
    return token is String && token.isNotEmpty ? token : null;
  }

  /// Fetches the full records of [ids], keyed by id with their modification
  /// times as values.
  ///
  /// Returns the records keyed by id.
  Future<Map<String, OsvVulnerability>> _fetchAll(
    Map<String, String> ids,
  ) async {
    final records = await mapWithConcurrency(
      ids.entries,
      transport.concurrency,
      (entry) => _fetch(entry.key, entry.value),
    );
    return <String, OsvVulnerability>{
      for (final record in records) record.id: record,
    };
  }

  /// Fetches the record of [id], using the cache when [modified] matches.
  ///
  /// Returns the record.
  ///
  /// Throws an [UnavailableException] when the record cannot be fetched.
  Future<OsvVulnerability> _fetch(String id, String modified) async {
    final cached = cache.read(id, modified);
    if (cached != null) {
      return cached;
    }
    final uri = Uri.parse('$baseUrl/v1/vulns/${Uri.encodeComponent(id)}');
    final result = await transport.get(uri);
    if (!result.isSuccess) {
      throw UnavailableException(
        'OSV.dev returned HTTP ${result.statusCode} for $uri.',
      );
    }
    final json = result.jsonObject('OSV.dev');
    cache.write(id, json);
    final record = OsvVulnerability.fromJson(json);
    return record.id == id
        ? record
        : OsvVulnerability.fromJson(<String, Object?>{...json, 'id': id});
  }
}
