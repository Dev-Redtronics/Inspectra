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

import 'package:inspectra/src/model/inspectra_exception.dart';

/// A fully received HTTP response.
final class HttpResult {
  /// Creates a result from the [statusCode], the lower-cased response
  /// [headers] and the raw [bodyBytes] received for [uri].
  const HttpResult({
    required this.uri,
    required this.statusCode,
    required this.headers,
    required this.bodyBytes,
  });

  /// The requested URI.
  final Uri uri;

  /// The HTTP status code.
  final int statusCode;

  /// The response headers with lower-case names; repeated headers are joined
  /// with a comma.
  final Map<String, String> headers;

  /// The raw response body.
  final Uint8List bodyBytes;

  /// Whether the status code is in the `2xx` range.
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Whether the status code is `404 Not Found`.
  bool get isNotFound => statusCode == 404;

  /// The body decoded as UTF-8, replacing malformed sequences.
  String get text => utf8.decode(bodyBytes, allowMalformed: true);

  /// The delay requested by a `Retry-After` header given in seconds, or
  /// `null` when the header is absent or uses the HTTP date format.
  Duration? get retryAfter {
    final int? seconds = int.tryParse(headers['retry-after'] ?? '');
    if (seconds == null || seconds < 0) {
      return null;
    }
    return Duration(seconds: seconds);
  }

  /// The target of a redirect response, resolved against [uri], or `null`
  /// when there is no `Location` header.
  Uri? get location {
    final String? value = headers['location'];
    if (value == null) {
      return null;
    }
    return uri.resolve(value);
  }

  /// Decodes the body as a JSON object.
  ///
  /// [service] names the remote service in the error message, for example
  /// `pub.dev`.
  ///
  /// Returns the decoded object.
  ///
  /// Throws an [UnavailableException] when the body is not a JSON object,
  /// because a malformed answer means the verification could not complete.
  Map<String, Object?> jsonObject(String service) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw UnavailableException(
        '$service returned a response for $uri that is not valid JSON.',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw UnavailableException(
        '$service returned a response for $uri that is not a JSON object.',
      );
    }
    return decoded;
  }
}
