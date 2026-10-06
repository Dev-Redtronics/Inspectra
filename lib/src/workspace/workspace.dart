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

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/pub/project_discovery.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/pub/pubspec_locator.dart';
import 'package:inspectra/src/pub/pubspec_parser.dart';
import 'package:inspectra/src/util/display_path.dart';
import 'package:inspectra/src/workspace/workspace_member.dart';
import 'package:path/path.dart' as p;

/// A pub workspace: the root `pubspec.yaml` with a `workspace:` list and
/// the packages that list names, nested workspaces included.
final class Workspace {
  /// Creates the workspace in [root] with its [members], the root first;
  /// [missing] are the `workspace:` entries that name no package and
  /// [unlisted] the packages below the root that declare
  /// `resolution: workspace` without being listed.
  const Workspace({
    required this.root,
    required this.members,
    this.missing = const <(WorkspaceMember, String)>[],
    this.unlisted = const <String>[],
  });

  /// Reads the workspace whose root is [directory]; paths in findings are
  /// relative to [workingDirectory].
  ///
  /// Returns the workspace, or `null` when [directory] has no
  /// `pubspec.yaml` with a `workspace:` list.
  ///
  /// Throws an [InvalidInputException] for a malformed pubspec.
  static Workspace? load(String directory, {String? workingDirectory}) {
    final String root = p.normalize(p.absolute(directory));
    final String shownFrom = workingDirectory ?? root;
    final WorkspaceMember? rootMember = _member(root, root, shownFrom);
    if (rootMember == null || rootMember.pubspec.workspace.isEmpty) {
      return null;
    }
    final members = <WorkspaceMember>[rootMember];
    final missing = <(WorkspaceMember, String)>[];
    final pending = <WorkspaceMember>[rootMember];
    while (pending.isNotEmpty) {
      final WorkspaceMember parent = pending.removeAt(0);
      for (final String entry in parent.pubspec.workspace) {
        final List<String> directories = _expand(parent.directory, entry);
        if (directories.isEmpty) {
          missing.add((parent, entry));
        }
        for (final path in directories) {
          final bool known = members.any(
            (member) => p.equals(member.directory, path),
          );
          final WorkspaceMember? member = known
              ? null
              : _member(path, root, shownFrom);
          if (member != null) {
            members.add(member);
            pending.add(member);
          }
        }
      }
    }
    final unlisted = <String>[
      for (final String pubspecPath in ProjectDiscovery(
        root,
      ).find('pubspec.yaml', recursive: true))
        if (!members.any(
              (member) => p.equals(member.pubspecPath, pubspecPath),
            ) &&
            _declaresWorkspace(pubspecPath))
          displayPath(pubspecPath, shownFrom),
    ];
    return Workspace(
      root: root,
      members: List<WorkspaceMember>.unmodifiable(members),
      missing: missing,
      unlisted: unlisted,
    );
  }

  /// Finds the names of the packages of the workspace the package in
  /// [directory] with [pubspec] belongs to, as its root or a member.
  ///
  /// Returns the names, empty for a package outside every workspace.
  ///
  /// Throws an [InvalidInputException] for a malformed pubspec of the
  /// workspace.
  static Set<String> packagesAround(String directory, Pubspec pubspec) {
    final String start = p.normalize(p.absolute(directory));
    if (pubspec.workspace.isNotEmpty) {
      return _names(load(start));
    }
    if (!pubspec.isWorkspaceMember) {
      return const <String>{};
    }
    String current = p.dirname(start);
    while (true) {
      final Workspace? workspace = load(current);
      final bool contains =
          workspace?.members.any(
            (member) => p.equals(member.directory, start),
          ) ??
          false;
      if (contains) {
        return _names(workspace);
      }
      final String parent = p.dirname(current);
      if (parent == current) {
        return const <String>{};
      }
      current = parent;
    }
  }

  /// Returns the names of the members of [workspace], none for `null`.
  static Set<String> _names(Workspace? workspace) => <String>{
    for (final WorkspaceMember member
        in workspace?.members ?? const <WorkspaceMember>[])
      member.name,
  };

  /// The absolute directory of the workspace root.
  final String root;

  /// Every package of the workspace, the root first.
  final List<WorkspaceMember> members;

  /// The `workspace:` entries that name no directory with a
  /// `pubspec.yaml`, with the member that lists them.
  final List<(WorkspaceMember, String)> missing;

  /// The pubspecs below the root that declare `resolution: workspace` but
  /// that no `workspace:` list names, relative to the working directory.
  final List<String> unlisted;

  /// Finds the member called [name].
  ///
  /// Returns the member, or `null` when no package of the workspace has
  /// that name.
  WorkspaceMember? named(String name) =>
      members.where((member) => member.name == name).firstOrNull;

  /// Finds the member that contains the file at [path], relative to the
  /// root with `/` separators: the one with the longest directory.
  ///
  /// Returns the member, the root for files outside every other member.
  WorkspaceMember memberOf(String path) {
    WorkspaceMember best = members.first;
    for (final WorkspaceMember member in members.skip(1)) {
      final bool inside =
          path == member.path || path.startsWith('${member.path}/');
      if (inside && member.path.length > best.path.length) {
        best = member;
      }
    }
    return best;
  }

  /// Reads the package in [directory] of the workspace in [root], shown
  /// relative to [workingDirectory].
  ///
  /// Returns the member, or `null` without a `pubspec.yaml`.
  ///
  /// Throws an [InvalidInputException] for a malformed pubspec.
  static WorkspaceMember? _member(
    String directory,
    String root,
    String workingDirectory,
  ) {
    final file = File(p.join(directory, 'pubspec.yaml'));
    if (!file.existsSync()) {
      return null;
    }
    final String content = file.readAsStringSync();
    final String shown = displayPath(file.path, workingDirectory);
    final Pubspec pubspec = const PubspecParser().parse(content, path: shown);
    final String relative = p.relative(directory, from: root);
    return WorkspaceMember(
      directory: p.normalize(directory),
      path: p.posix.joinAll(p.split(relative)),
      pubspecPath: p.normalize(file.path),
      pubspec: pubspec,
      locator: PubspecLocator.parse(content, shown),
    );
  }

  /// Resolves the `workspace:` [entry] of the package in [directory], a
  /// path or a glob.
  ///
  /// Returns the absolute directories with a `pubspec.yaml`, sorted.
  static List<String> _expand(String directory, String entry) {
    final bool isGlob = entry.contains(RegExp(r'[*?\[{]'));
    final candidates = isGlob
        ? <String>[
            for (final FileSystemEntity entity in Glob(
              entry,
            ).listSync(root: directory, followLinks: false))
              if (entity is Directory) p.normalize(entity.path),
          ]
        : <String>[p.normalize(p.join(directory, entry))];
    return candidates
        .where((path) => File(p.join(path, 'pubspec.yaml')).existsSync())
        .toList()
      ..sort();
  }

  /// Whether the pubspec at [path] declares `resolution: workspace`.
  static bool _declaresWorkspace(String path) => RegExp(
    r'^resolution:\s*workspace\s*$',
    multiLine: true,
  ).hasMatch(File(path).readAsStringSync());
}
