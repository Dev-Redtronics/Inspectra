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

/// The packages a package imports, split by where the importing code runs.
final class PackageImports {
  /// Creates the imports of [runtime] code and [development] code.
  const PackageImports({required this.runtime, required this.development});

  /// The packages imported or exported by `lib/` and `bin/`, the code that
  /// runs in the package's users.
  final Set<String> runtime;

  /// The packages imported by tests, tools, examples and benchmarks.
  final Set<String> development;
}
