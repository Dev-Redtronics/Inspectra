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

import 'dart:io';

import 'package:inspectra/src/pub/lockfile.dart';
import 'package:inspectra/src/pub/lockfile_parser.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/pub/pubspec_locator.dart';
import 'package:inspectra/src/util/display_path.dart';
import 'package:inspectra/src/util/files.dart';
import 'package:path/path.dart' as p;

/// One package as the dependency policy checks it: its pubspec, where it
/// lives, and the lockfile it resolves with.
final class PolicySource {
  /// Creates the source of the package in [packageRoot] with its parsed
  /// [pubspec] and its [locator]; [lockfile] is the `pubspec.lock` that
  /// resolves it, located by [lockLocator], and [ownsLockfile] tells
  /// whether the lockfile lies next to the pubspec rather than at a
  /// workspace root.
  PolicySource({
    required this.pubspec,
    required this.locator,
    required this.packageRoot,
    this.lockfile,
    PubspecLocator? lockLocator,
    this.ownsLockfile = false,
  }) : lockLocator =
           lockLocator ?? PubspecLocator.parse('', lockfile?.path ?? '');

  /// Describes the package whose `pubspec.yaml` at [pubspecPath] has the
  /// [content] that parsed to [pubspec]; paths in findings are relative to
  /// [workingDirectory].
  ///
  /// The lockfile is the `pubspec.lock` next to the pubspec, or for a
  /// member of a pub workspace the one of the workspace root.
  ///
  /// Returns the source.
  ///
  /// Throws an `InvalidInputException` when the lockfile is malformed.
  factory PolicySource.forPubspec({
    required String pubspecPath,
    required String content,
    required Pubspec pubspec,
    required String workingDirectory,
  }) {
    final String packageRoot = p.dirname(pubspecPath);
    final local = File(p.join(packageRoot, 'pubspec.lock'));
    final File? lock = local.existsSync()
        ? local
        : pubspec.isWorkspaceMember
        ? findUpwards(p.dirname(packageRoot), 'pubspec.lock')
        : null;
    final locator = PubspecLocator.parse(
      content,
      displayPath(pubspecPath, workingDirectory),
    );
    if (lock == null) {
      return PolicySource(
        pubspec: pubspec,
        locator: locator,
        packageRoot: packageRoot,
      );
    }
    final String lockContent = lock.readAsStringSync();
    final String lockDisplay = displayPath(lock.path, workingDirectory);
    return PolicySource(
      pubspec: pubspec,
      locator: locator,
      packageRoot: packageRoot,
      lockfile: const LockfileParser().parse(lockContent, path: lockDisplay),
      lockLocator: PubspecLocator.parse(lockContent, lockDisplay),
      ownsLockfile: p.equals(p.dirname(lock.path), packageRoot),
    );
  }

  /// The parsed pubspec.
  final Pubspec pubspec;

  /// Finds the lines of the pubspec.
  final PubspecLocator locator;

  /// The directory of the package.
  final String packageRoot;

  /// The lockfile that resolves the package, if any.
  final Lockfile? lockfile;

  /// Finds the lines of the lockfile.
  final PubspecLocator lockLocator;

  /// Whether [lockfile] belongs to this package rather than to the
  /// workspace it is a member of.
  final bool ownsLockfile;
}
