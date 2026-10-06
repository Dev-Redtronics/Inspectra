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

import 'package:inspectra/src/io/clock.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/net/http_transport.dart';
import 'package:inspectra/src/pub/pub_package.dart';
import 'package:inspectra/src/pub/pub_package_cache.dart';
import 'package:inspectra/src/pub/pub_repository_client.dart';

/// The version listings of packages from any registry, read through a
/// [PubPackageCache].
final class RegistryListings {
  /// Creates the listings fetched through [transport], cached in [cache]
  /// as of the [clock].
  RegistryListings({
    required this.transport,
    required this.cache,
    required this.clock,
  });

  /// The HTTP transport.
  final HttpTransport transport;

  /// The cache of listings.
  final PubPackageCache cache;

  /// The clock that decides whether a cached listing is fresh.
  final Clock clock;

  /// One client per registry.
  final _clients = <String, PubRepositoryClient>{};

  /// Fetches the listing of [name] from [registry], from the cache while it
  /// is fresh.
  ///
  /// Returns the listing, or `null` when the registry does not know the
  /// package.
  ///
  /// Throws an [UnavailableException] when the registry cannot be queried.
  Future<PubPackage?> lookup(String name, String registry) async {
    final String baseUrl = registry.replaceAll(RegExp(r'/+$'), '');
    final DateTime now = clock.now();
    final PubPackage? cached = cache.read(baseUrl, name, now);
    if (cached != null) {
      return cached;
    }
    final PubRepositoryClient client = _clients.putIfAbsent(
      baseUrl,
      () => PubRepositoryClient(transport: transport, baseUrl: baseUrl),
    );
    final PubPackage? listing = await client.package(name);
    if (listing != null) {
      cache.write(baseUrl, listing, now);
    }
    return listing;
  }
}
