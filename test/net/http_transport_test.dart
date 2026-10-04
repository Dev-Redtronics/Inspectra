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

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/net/http_transport.dart';
import 'package:test/test.dart';

import '../support/fake_http_server.dart';
import '../support/fake_response.dart';

/// Tests the HTTP transport against a loopback server.
void main() {
  late FakeHttpServer server;
  late List<Duration> sleeps;

  setUp(() async {
    server = await FakeHttpServer.start();
    sleeps = <Duration>[];
  });
  tearDown(() => server.close());

  /// Creates a transport with the given [offline] mode.
  HttpTransport transport({bool offline = false}) => HttpTransport(
    config: NetworkConfig(
      offline: offline,
      retryBaseDelay: const Duration(milliseconds: 10),
    ),
    environment: const Environment(<String, String>{}),
    sleep: (delay) async => sleeps.add(delay),
  );

  test('retries transient failures and returns the final response', () async {
    var calls = 0;
    server.onDynamic('GET', '/flaky', (_) {
      calls++;
      return calls < 3
          ? const FakeResponse(
              503,
              headers: <String, String>{'retry-after': '2'},
            )
          : FakeResponse.text('ok');
    });
    final result = await transport().get(Uri.parse('${server.baseUrl}/flaky'));
    expect(result.statusCode, 200);
    expect(result.text, 'ok');
    expect(sleeps, <Duration>[
      const Duration(seconds: 2),
      const Duration(seconds: 2),
    ]);
  });

  test('returns the last retryable response when attempts run out', () async {
    server.on('GET', '/down', const FakeResponse(503));
    final result = await transport().get(Uri.parse('${server.baseUrl}/down'));
    expect(result.statusCode, 503);
    expect(sleeps, hasLength(2));
  });

  test('does not retry client errors', () async {
    final result = await transport().get(
      Uri.parse('${server.baseUrl}/missing'),
    );
    expect(result.isNotFound, isTrue);
    expect(sleeps, isEmpty);
  });

  test('rejects responses larger than the limit', () async {
    server.on('GET', '/big', FakeResponse.text('x' * 100));
    expect(
      () => transport().get(Uri.parse('${server.baseUrl}/big'), maxBytes: 10),
      throwsA(isA<UnavailableException>()),
    );
  });

  test('never connects in offline mode', () async {
    expect(
      () => transport(offline: true).get(Uri.parse(server.baseUrl)),
      throwsA(isA<UnavailableException>()),
    );
    expect(
      await transport(
        offline: true,
      ).probe(Uri.parse(server.baseUrl), const Duration(seconds: 1)),
      isFalse,
    );
    expect(server.requests, isEmpty);
  });

  test('probe treats any HTTP answer as reachable', () async {
    final reachable = await transport().probe(
      Uri.parse('${server.baseUrl}/'),
      const Duration(seconds: 2),
    );
    expect(reachable, isTrue);
  });

  test('reports unreachable hosts after all attempts', () async {
    final port = Uri.parse(server.baseUrl).port;
    await server.close();
    expect(
      () => transport().get(Uri.parse('http://127.0.0.1:$port/')),
      throwsA(isA<UnavailableException>()),
    );
  });
}
