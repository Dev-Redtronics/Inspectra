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

import 'dart:convert';

/// A canned HTTP response served by the fake HTTP server.
final class FakeResponse {
  /// Creates a response with [status], raw [body] bytes and [headers].
  const FakeResponse(
    this.status, {
    this.body = const <int>[],
    this.headers = const <String, String>{},
  });

  /// Creates a `200` response with a JSON encoded [json] body.
  ///
  /// Returns the response.
  factory FakeResponse.json(Object json, {int status = 200}) => FakeResponse(
    status,
    body: utf8.encode(jsonEncode(json)),
    headers: const <String, String>{'content-type': 'application/json'},
  );

  /// Creates a `200` response with a UTF-8 text [body].
  ///
  /// Returns the response.
  factory FakeResponse.text(String body, {int status = 200}) =>
      FakeResponse(status, body: utf8.encode(body));

  /// The HTTP status code.
  final int status;

  /// The raw body.
  final List<int> body;

  /// The response headers.
  final Map<String, String> headers;
}
