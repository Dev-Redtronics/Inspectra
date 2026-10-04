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

import 'dart:convert';
import 'dart:typed_data';

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/net/http_result.dart';
import 'package:test/test.dart';

/// Tests response helpers.
void main() {
  /// Creates a result with [body] and [headers].
  HttpResult result(String body, {Map<String, String> headers = const {}}) =>
      HttpResult(
        uri: Uri.parse('https://pub.dev/api/x'),
        statusCode: 302,
        headers: headers,
        bodyBytes: Uint8List.fromList(utf8.encode(body)),
      );

  test('parses Retry-After seconds and resolves redirects', () {
    final redirect = result(
      '',
      headers: <String, String>{'retry-after': '5', 'location': '/other'},
    );
    expect(redirect.retryAfter, const Duration(seconds: 5));
    expect('${redirect.location}', 'https://pub.dev/other');
    expect(result('').retryAfter, isNull);
    expect(result('').location, isNull);
  });

  test('decodes JSON objects and rejects everything else', () {
    expect(result('{"a":1}').jsonObject('svc'), <String, Object?>{'a': 1});
    expect(
      () => result('[1]').jsonObject('svc'),
      throwsA(isA<UnavailableException>()),
    );
    expect(
      () => result('<html>').jsonObject('svc'),
      throwsA(isA<UnavailableException>()),
    );
  });
}
