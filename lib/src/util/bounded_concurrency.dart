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

/// Applies [action] to every element of [items] with at most [concurrency]
/// invocations in flight at the same time.
///
/// The results are returned in the order of [items], independent of the order
/// in which the actions complete. The first error thrown by an action is
/// rethrown once all running actions have settled, so no work is left
/// dangling. A [concurrency] below one is treated as one.
///
/// This keeps Inspectra polite towards OSV.dev and pub.dev: fetching the
/// details of two hundred advisories never opens two hundred connections.
///
/// Returns the results in input order.
Future<List<R>> mapWithConcurrency<T, R>(
  Iterable<T> items,
  int concurrency,
  Future<R> Function(T item) action,
) async {
  final List<T> inputs = items.toList();
  final results = List<R?>.filled(inputs.length, null);
  var nextIndex = 0;
  Future<void> worker() async {
    while (nextIndex < inputs.length) {
      final index = nextIndex;
      nextIndex++;
      results[index] = await action(inputs[index]);
    }
  }

  final workerCount = concurrency < 1 ? 1 : concurrency;
  final workers = List<Future<void>>.generate(
    workerCount < inputs.length ? workerCount : inputs.length,
    (_) => worker(),
  );
  await Future.wait(workers);
  return results.cast<R>();
}
