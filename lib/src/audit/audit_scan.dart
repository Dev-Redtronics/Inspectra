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

import '../model/finding.dart';
import '../pub/locked_package.dart';

/// The raw outcome of auditing one lockfile, before reporting policies are
/// applied.
final class AuditScan {
  /// Creates an audit outcome.
  const AuditScan({
    required this.lockfilePath,
    required this.scanned,
    required this.skipped,
    required this.findings,
  });

  /// The display path of the audited lockfile.
  final String lockfilePath;

  /// The packages that were checked against OSV.dev.
  final List<LockedPackage> scanned;

  /// The packages that could not be checked: Git, path and SDK sources and
  /// packages from private registries.
  final List<LockedPackage> skipped;

  /// One finding per vulnerable package and advisory.
  final List<Finding> findings;
}
