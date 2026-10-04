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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'fake_response.dart';

/// A real HTTP server on the loopback interface with scripted routes.
///
/// Tests point Inspectra's configurable URLs at [baseUrl], so the complete
/// production HTTP stack (transport, retries, size limits, checksum
/// verification) runs without any network access.
final class FakeHttpServer {
  /// Wraps the bound [_server].
  FakeHttpServer._(this._server);

  /// Starts a server on a free loopback port.
  ///
  /// Returns the running server.
  static Future<FakeHttpServer> start() async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final fake = FakeHttpServer._(server);
    server.listen((request) => unawaited(fake._handle(request)));
    return fake;
  }

  /// The underlying server.
  final HttpServer _server;

  /// Handlers keyed by `METHOD path`; each call may return a different
  /// response, which allows scripting retries.
  final _routes = <String, FakeResponse Function(String body)>{};

  /// Every received request as `METHOD path`, in order.
  final requests = <String>[];

  /// The base URL, for example `http://127.0.0.1:54321`.
  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  /// Serves [response] for [method] requests to [path].
  void on(String method, String path, FakeResponse response) {
    _routes['$method $path'] = (_) => response;
  }

  /// Serves the result of [handler], which receives the request body, for
  /// [method] requests to [path].
  void onDynamic(
    String method,
    String path,
    FakeResponse Function(String body) handler,
  ) {
    _routes['$method $path'] = handler;
  }

  /// Answers one [request] from the routes, or with `404`.
  Future<void> _handle(HttpRequest request) async {
    final String body = await utf8.decoder.bind(request).join();
    final key = '${request.method} ${request.uri.path}';
    requests.add(key);
    final FakeResponse Function(String body)? handler =
        _routes[key] ?? _routes['GET ${request.uri.path}'];
    final isHead = request.method == 'HEAD';
    final FakeResponse response =
        handler == null || (isHead && !_routes.containsKey(key))
        ? const FakeResponse(404)
        : handler(body);
    request.response.statusCode = response.status;
    response.headers.forEach(request.response.headers.set);
    if (!isHead) {
      request.response.add(response.body);
    }
    await request.response.close();
  }

  /// Stops the server.
  Future<void> close() => _server.close(force: true);
}
