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

import 'dart:math';

/// Decides whether and when a failed HTTP request is retried.
///
/// Retries use exponential back-off with full jitter, which spreads the load
/// when many CI jobs hit a rate limit at the same moment. A `Retry-After`
/// header sent by the server always takes precedence, capped at [maxDelay].
final class RetryPolicy {
  /// Creates a policy allowing [maxAttempts] attempts in total, starting with
  /// [baseDelay] between attempts.
  ///
  /// [random] can be seeded in tests to make the jitter deterministic.
  RetryPolicy({
    required this.maxAttempts,
    required this.baseDelay,
    this.maxDelay = const Duration(seconds: 30),
    Random? random,
  }) : _random = random ?? Random();

  /// The total number of attempts, including the first one.
  final int maxAttempts;

  /// The delay before the second attempt; it doubles for every retry.
  final Duration baseDelay;

  /// The upper bound of any single delay.
  final Duration maxDelay;

  /// The source of jitter.
  final Random _random;

  /// The HTTP status codes that indicate a transient server side problem.
  static const Set<int> _retryableStatusCodes = <int>{
    408,
    425,
    429,
    500,
    502,
    503,
    504,
  };

  /// Whether a response with [statusCode] should be retried.
  ///
  /// Returns `true` for timeouts, rate limits and transient server errors.
  bool isRetryableStatus(int statusCode) =>
      _retryableStatusCodes.contains(statusCode);

  /// Computes the delay before the attempt following attempt number
  /// [attempt] (one-based).
  ///
  /// When the server sent [retryAfter], that value is used, capped at
  /// [maxDelay]. Otherwise the delay is a random value between half and the
  /// full exponential back-off `baseDelay * 2^(attempt - 1)`.
  ///
  /// Returns the delay to wait.
  Duration delayFor(int attempt, {Duration? retryAfter}) {
    if (retryAfter != null) {
      return retryAfter > maxDelay ? maxDelay : retryAfter;
    }
    final exponent = attempt - 1 < 0 ? 0 : attempt - 1;
    final backOff = baseDelay.inMilliseconds * pow(2, exponent);
    final capped = min(backOff.toInt(), maxDelay.inMilliseconds);
    final half = capped ~/ 2;
    final jitter = half == 0 ? 0 : _random.nextInt(half + 1);
    return Duration(milliseconds: half + jitter);
  }
}
