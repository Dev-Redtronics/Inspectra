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

import 'package:inspectra/src/pub/lockfile_entry.dart';

/// A parsed `pubspec.lock` file.
final class Lockfile {
  /// Creates a lockfile read from [path] containing [packages].
  const Lockfile({required this.path, required this.packages});

  /// The file the lockfile was read from.
  final String path;

  /// All packages, direct dependencies first and then sorted by name.
  final List<LockfileEntry> packages;

  /// The registry URLs considered public, which OSV.dev indexes.
  static const publicRegistries = <String>{
    'https://pub.dev',
    'https://pub.dartlang.org',
  };

  /// Whether [hostedUrl] points at a public registry.
  ///
  /// [mirrorUrl] is the configured pub repository; a mirror of pub.dev
  /// serves the same packages and is therefore treated as public.
  ///
  /// Returns `true` for public registries.
  static bool isPublicRegistry(String? hostedUrl, String mirrorUrl) {
    if (hostedUrl == null) {
      return true;
    }
    final String normalised = hostedUrl.replaceAll(RegExp(r'/+$'), '');
    return publicRegistries.contains(normalised) || normalised == mirrorUrl;
  }

  /// The packages hosted on a public registry, which can be audited against
  /// OSV.dev.
  ///
  /// Returns the auditable packages.
  List<LockfileEntry> auditable(String mirrorUrl) => packages
      .where(
        (pkg) => pkg.isHosted && isPublicRegistry(pkg.hostedUrl, mirrorUrl),
      )
      .toList();

  /// The packages hosted on a private registry. They are not covered by
  /// OSV.dev and are the targets of dependency confusion attacks.
  ///
  /// Returns the privately hosted packages.
  List<LockfileEntry> privatelyHosted(String mirrorUrl) => packages
      .where(
        (pkg) => pkg.isHosted && !isPublicRegistry(pkg.hostedUrl, mirrorUrl),
      )
      .toList();

  /// The packages resolved from `git`, `path` or `sdk` sources, which no
  /// advisory database covers.
  ///
  /// Returns the unauditable packages.
  List<LockfileEntry> get unhosted =>
      packages.where((pkg) => !pkg.isHosted).toList();
}
