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
import 'dart:typed_data';

import 'package:inspectra/src/config/network_config.dart';
import 'package:inspectra/src/io/environment.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/net/http_result.dart';
import 'package:inspectra/src/net/retry_policy.dart';
import 'package:inspectra/src/version.dart';

/// The only component that performs HTTP requests.
///
/// It is built on `dart:io` `HttpClient`, so Inspectra needs no HTTP package,
/// and adds what enterprise networks require:
///
/// * proxies from `network.proxy` or the standard proxy variables;
/// * additional certificate authorities for TLS intercepting proxies;
/// * an identifying `User-Agent`;
/// * timeouts, bounded retries with back-off and `Retry-After` support;
/// * a hard limit on response sizes;
/// * a global offline switch that guarantees no connection is opened.
final class HttpTransport {
  /// Creates a transport configured by [config].
  ///
  /// [environment] supplies the proxy variables. [sleep] waits between
  /// retries and is replaced in tests to avoid real delays.
  ///
  /// Throws an [InvalidInputException] when the configured certificate file
  /// cannot be loaded.
  factory HttpTransport({
    required NetworkConfig config,
    required Environment environment,
    Future<void> Function(Duration delay)? sleep,
    RetryPolicy? retryPolicy,
  }) {
    final client = HttpClient(context: _securityContext(config))
      ..connectionTimeout = config.timeout
      ..userAgent = userAgent
      ..findProxy = (uri) => _findProxy(uri, config, environment);
    final RetryPolicy policy =
        retryPolicy ??
        RetryPolicy(
          maxAttempts: config.maxAttempts < 1 ? 1 : config.maxAttempts,
          baseDelay: config.retryBaseDelay,
        );
    return HttpTransport._(client, config, policy, sleep ?? Future.delayed);
  }

  /// Creates a transport from already prepared parts.
  HttpTransport._(this._client, this._config, this._retryPolicy, this._sleep);

  /// The `User-Agent` sent with every request.
  static const userAgent =
      'inspectra/$inspectraVersion (+https://github.com/dev-redtronics/inspectra)';

  /// The default upper bound for response bodies: 64 MiB.
  static const int defaultMaxBytes = 64 * 1024 * 1024;

  /// The underlying `dart:io` client.
  final HttpClient _client;

  /// The network configuration.
  final NetworkConfig _config;

  /// The retry policy applied to idempotent requests.
  final RetryPolicy _retryPolicy;

  /// Waits for the given delay between retries.
  final Future<void> Function(Duration delay) _sleep;

  /// Whether the transport is in offline mode.
  bool get isOffline => _config.offline;

  /// The maximum number of concurrent requests to one service.
  int get concurrency => _config.concurrency < 1 ? 1 : _config.concurrency;

  /// Builds the TLS context, adding the configured certificate authorities.
  ///
  /// Returns `null` for the default context when nothing is configured.
  static SecurityContext? _securityContext(NetworkConfig config) {
    final String? certificates = config.caCertificates;
    if (certificates == null) {
      return null;
    }
    final context = SecurityContext(withTrustedRoots: true);
    try {
      context.setTrustedCertificates(certificates);
    } on TlsException catch (error) {
      throw InvalidInputException(
        'The CA certificate file "$certificates" (network.caCertificates) '
        'could not be loaded: ${error.message}',
      );
    } on FileSystemException {
      throw InvalidInputException(
        'The CA certificate file "$certificates" (network.caCertificates) '
        'does not exist.',
      );
    }
    return context;
  }

  /// Chooses the proxy for [uri].
  ///
  /// Returns `PROXY host:port` for the explicit proxy, otherwise the result of
  /// the standard environment lookup, which may be `DIRECT`.
  static String _findProxy(
    Uri uri,
    NetworkConfig config,
    Environment environment,
  ) {
    final String? explicit = config.proxy;
    if (explicit == null) {
      return HttpClient.findProxyFromEnvironment(
        uri,
        environment: environment.variables,
      );
    }
    final Uri proxyUri = Uri.parse(explicit);
    final credentials = proxyUri.userInfo.isEmpty
        ? ''
        : '${proxyUri.userInfo}@';
    return 'PROXY $credentials${proxyUri.host}:${proxyUri.port}';
  }

  /// Sends a `GET` request to [uri] with retries.
  ///
  /// [maxBytes] limits the body size, [followRedirects] controls redirect
  /// handling and [headers] adds request headers.
  ///
  /// Returns the response, including non-success responses.
  ///
  /// Throws an [UnavailableException] when offline, when the host cannot be
  /// reached after all attempts or when the body exceeds [maxBytes].
  Future<HttpResult> get(
    Uri uri, {
    int maxBytes = defaultMaxBytes,
    bool followRedirects = true,
    Map<String, String> headers = const <String, String>{},
  }) => _withRetries(
    uri,
    () => _attempt(
      'GET',
      uri,
      maxBytes: maxBytes,
      followRedirects: followRedirects,
      headers: headers,
    ),
  );

  /// Sends a `POST` request with a JSON encoded [body] to [uri].
  ///
  /// OSV.dev queries are idempotent, which is why they are retried like
  /// `GET` requests.
  ///
  /// Returns the response, including non-success responses.
  ///
  /// Throws an [UnavailableException] under the same conditions as [get].
  Future<HttpResult> postJson(
    Uri uri,
    Object body, {
    int maxBytes = defaultMaxBytes,
  }) {
    final Uint8List encoded = utf8.encode(jsonEncode(body));
    return _withRetries(
      uri,
      () => _attempt(
        'POST',
        uri,
        maxBytes: maxBytes,
        followRedirects: false,
        headers: const <String, String>{'content-type': 'application/json'},
        body: encoded,
      ),
    );
  }

  /// Checks with a single `HEAD` request whether [uri] can be reached within
  /// [timeout].
  ///
  /// Any HTTP response counts as reachable, because it proves that DNS, the
  /// proxy and TLS work. In offline mode no request is made.
  ///
  /// Returns `true` when the host answered.
  Future<bool> probe(Uri uri, Duration timeout) async {
    if (isOffline) {
      return false;
    }
    try {
      await _attempt(
        'HEAD',
        uri,
        maxBytes: 0,
        followRedirects: false,
        headers: const <String, String>{},
      ).timeout(timeout);
      return true;
    } on IOException {
      return false;
    } on TimeoutException {
      return false;
    } on UnavailableException {
      return false;
    }
  }

  /// Closes all idle connections; the transport must not be used afterwards.
  void close() => _client.close(force: true);

  /// Runs [attempt] until it yields a final response or attempts run out.
  ///
  /// Returns the final response.
  ///
  /// Throws an [UnavailableException] when offline or when every attempt
  /// failed with a network error.
  Future<HttpResult> _withRetries(
    Uri uri,
    Future<HttpResult> Function() attempt,
  ) async {
    if (isOffline) {
      throw UnavailableException(
        'Network access is disabled (offline mode), so ${uri.host} cannot be '
        'contacted.',
      );
    }
    var attemptNumber = 0;
    while (true) {
      attemptNumber++;
      final bool isLastAttempt = attemptNumber >= _retryPolicy.maxAttempts;
      HttpResult? result;
      Object? failure;
      try {
        result = await attempt();
      } on IOException catch (error) {
        failure = error;
      } on TimeoutException catch (error) {
        failure = error;
      }
      final bool retryable =
          result == null || _retryPolicy.isRetryableStatus(result.statusCode);
      if (result != null && (!retryable || isLastAttempt)) {
        return result;
      }
      if (isLastAttempt) {
        throw UnavailableException(
          'Could not reach ${uri.host} after $attemptNumber attempt(s): '
          '$failure',
        );
      }
      final Duration delay = _retryPolicy.delayFor(
        attemptNumber,
        retryAfter: result?.retryAfter,
      );
      await _sleep(delay);
    }
  }

  /// Performs exactly one request.
  ///
  /// Returns the fully read response.
  ///
  /// Throws an [UnavailableException] when the body exceeds [maxBytes], and
  /// lets I/O and timeout errors propagate for the retry loop.
  Future<HttpResult> _attempt(
    String method,
    Uri uri, {
    required int maxBytes,
    required bool followRedirects,
    required Map<String, String> headers,
    List<int>? body,
  }) async {
    final Duration timeout = _config.timeout;
    final HttpClientRequest request = await _client
        .openUrl(method, uri)
        .timeout(timeout);
    request
      ..followRedirects = followRedirects
      ..maxRedirects = 5;
    headers.forEach(request.headers.set);
    if (body != null) {
      request
        ..contentLength = body.length
        ..add(body);
    }
    final HttpClientResponse response = await request.close().timeout(timeout);
    final Uint8List bytes = await _readBody(
      response,
      maxBytes,
      uri,
    ).timeout(timeout);
    final responseHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      responseHeaders[name.toLowerCase()] = values.join(',');
    });
    return HttpResult(
      uri: uri,
      statusCode: response.statusCode,
      headers: responseHeaders,
      bodyBytes: bytes,
    );
  }

  /// Reads the body of [response], enforcing [maxBytes].
  ///
  /// Returns the body bytes.
  ///
  /// Throws an [UnavailableException] when the body is larger than allowed.
  Future<Uint8List> _readBody(
    HttpClientResponse response,
    int maxBytes,
    Uri uri,
  ) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
      if (builder.length > maxBytes) {
        throw UnavailableException(
          'The response from $uri exceeded the limit of $maxBytes bytes.',
        );
      }
    }
    return builder.takeBytes();
  }
}
