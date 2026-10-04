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

import 'package:inspectra/src/osv/osv_range.dart';

/// One `affected[]` entry of an OSV record.
final class OsvAffected {
  /// Creates an affected entry for [packageName] in [ecosystem].
  const OsvAffected({
    required this.packageName,
    required this.ecosystem,
    this.ranges = const <OsvRange>[],
    this.severity,
  });

  /// The affected package.
  final String packageName;

  /// The ecosystem, `Pub` for Dart packages.
  final String ecosystem;

  /// The affected version ranges.
  final List<OsvRange> ranges;

  /// A severity from `database_specific` or `ecosystem_specific`, if any.
  final String? severity;
}
