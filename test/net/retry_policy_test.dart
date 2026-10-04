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

import 'package:inspectra/src/net/retry_policy.dart';
import 'package:test/test.dart';

/// Tests retry decisions and back-off delays.
void main() {
  final policy = RetryPolicy(
    maxAttempts: 3,
    baseDelay: const Duration(seconds: 1),
    random: Random(1),
  );

  test('retries rate limits and transient server errors only', () {
    expect(policy.isRetryableStatus(429), isTrue);
    expect(policy.isRetryableStatus(503), isTrue);
    expect(policy.isRetryableStatus(404), isFalse);
    expect(policy.isRetryableStatus(400), isFalse);
  });

  test('doubles the back-off with jitter between half and full', () {
    final first = policy.delayFor(1);
    final third = policy.delayFor(3);
    expect(first.inMilliseconds, inInclusiveRange(500, 1000));
    expect(third.inMilliseconds, inInclusiveRange(2000, 4000));
  });

  test('honours Retry-After up to the maximum delay', () {
    expect(
      policy.delayFor(1, retryAfter: const Duration(seconds: 7)),
      const Duration(seconds: 7),
    );
    expect(
      policy.delayFor(1, retryAfter: const Duration(hours: 1)),
      policy.maxDelay,
    );
  });
}
