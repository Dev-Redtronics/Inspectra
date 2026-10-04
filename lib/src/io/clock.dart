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

/// A source of the current time.
///
/// Trust rules such as "published less than 24 hours ago" and ignore rule
/// expiry depend on the current time; injecting a clock keeps those rules
/// deterministic under test.
final class Clock {
  /// Creates a clock that asks [_now] for the current time.
  const Clock(this._now);

  /// Creates a clock backed by the system time.
  const Clock.system() : _now = DateTime.now;

  /// The function that produces the current time.
  final DateTime Function() _now;

  /// Returns the current time in UTC.
  DateTime now() => _now().toUtc();
}
