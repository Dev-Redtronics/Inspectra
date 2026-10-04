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

import 'package:path/path.dart' as p;

import '../io/environment.dart';
import 'host_platform.dart';
import 'operating_system.dart';

/// Resolves the per-user cache directory that Inspectra writes to.
///
/// Downloaded Trivy binaries and cached OSV.dev advisories live below this
/// directory. It follows the conventions of each operating system:
///
/// * `INSPECTRA_CACHE_DIR`, when set, always wins;
/// * Windows: `%LOCALAPPDATA%\inspectra`;
/// * macOS: `~/Library/Caches/inspectra`;
/// * Linux and others: `$XDG_CACHE_HOME/inspectra` or `~/.cache/inspectra`.
final class CacheDirectory {
  /// Creates a resolver for the given [environment] and [host].
  const CacheDirectory({required this.environment, required this.host});

  /// The environment variables consulted for overrides and home folders.
  final Environment environment;

  /// The platform whose conventions apply.
  final HostPlatform host;

  /// The application folder name appended to the platform cache root.
  static const String _applicationFolder = 'inspectra';

  /// Resolves the cache directory.
  ///
  /// Returns the absolute path, or `null` when no home directory can be
  /// determined, in which case callers fall back to the system temp folder.
  String? resolve() {
    final override = environment['INSPECTRA_CACHE_DIR'];
    if (override != null) {
      return override;
    }
    final root = _platformRoot();
    if (root == null) {
      return null;
    }
    return p.join(root, _applicationFolder);
  }

  /// Determines the cache root of the current platform.
  ///
  /// Returns the root folder, or `null` when it cannot be determined.
  String? _platformRoot() {
    final home = environment.homeDirectory;
    return switch (host.operatingSystem) {
      OperatingSystem.windows => environment['LOCALAPPDATA'] ?? home,
      OperatingSystem.macos => _joinOrNull(home, 'Library/Caches'),
      OperatingSystem.linux => _xdgCache(home),
      OperatingSystem.other => _xdgCache(home),
    };
  }

  /// Applies the XDG base directory convention for caches.
  ///
  /// Returns `$XDG_CACHE_HOME` or `<home>/.cache`, or `null` without a home.
  String? _xdgCache(String? home) {
    final xdg = environment['XDG_CACHE_HOME'];
    if (xdg != null) {
      return xdg;
    }
    return _joinOrNull(home, '.cache');
  }

  /// Joins [base] and [child] when [base] is known.
  ///
  /// Returns the joined path, or `null` when [base] is `null`.
  String? _joinOrNull(String? base, String child) {
    if (base == null) {
      return null;
    }
    return p.join(base, child);
  }
}
