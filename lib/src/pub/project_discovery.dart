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

import 'package:inspectra/src/workspace/workspace.dart';
import 'package:inspectra/src/workspace/workspace_member.dart';
import 'package:path/path.dart' as p;

/// Finds the Dart packages inside a directory tree.
///
/// Monorepos and pub workspaces contain many packages; with recursion enabled
/// every `pubspec.lock` below the root is audited, and a pub workspace can
/// be read by its `workspace:` list. Build output, tool caches, hidden
/// folders and vendored dependencies are skipped.
final class ProjectDiscovery {
  /// Creates a discovery rooted at [root].
  const ProjectDiscovery(this.root);

  /// The directory to search.
  final String root;

  /// Directory names that never contain project sources.
  static const _skippedDirectories = <String>{
    'build',
    'node_modules',
    'Pods',
    'ephemeral',
  };

  /// Finds files named [fileName].
  ///
  /// Without [recursive] only the root directory is checked. With
  /// [workspace], the pubspecs of a pub workspace root are the ones of its
  /// members, the packages its `workspace:` list names, instead of every
  /// pubspec below it.
  ///
  /// Returns the absolute paths in a stable, sorted order.
  ///
  /// Throws an `InvalidInputException` for a malformed pubspec of a
  /// workspace.
  List<String> find(
    String fileName, {
    required bool recursive,
    bool workspace = false,
  }) {
    final direct = File(p.join(root, fileName));
    if (!recursive) {
      return direct.existsSync() ? <String>[direct.path] : const <String>[];
    }
    final Workspace? members = workspace && fileName == 'pubspec.yaml'
        ? Workspace.load(root)
        : null;
    if (members != null) {
      return <String>[
        for (final WorkspaceMember member in members.members)
          member.pubspecPath,
      ]..sort();
    }
    final matches = <String>[];
    _walk(Directory(root), fileName, matches);
    matches.sort();
    return matches;
  }

  /// Recursively collects files named [fileName] below [directory].
  void _walk(Directory directory, String fileName, List<String> matches) {
    final List<FileSystemEntity> children;
    try {
      children = directory.listSync(followLinks: false);
    } on FileSystemException {
      return;
    }
    for (final child in children) {
      final String name = p.basename(child.path);
      if (child is File && name == fileName) {
        matches.add(child.path);
      }
      final bool skipped =
          name.startsWith('.') || _skippedDirectories.contains(name);
      if (child is Directory && !skipped) {
        _walk(child, fileName, matches);
      }
    }
  }
}
