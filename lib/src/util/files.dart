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
import 'package:path/path.dart' as p;

/// The file at [relative] below [start] or below the closest of its parent
/// directories that has one, or `null`.
///
/// A pub workspace keeps `pubspec.lock` and `.dart_tool` in its root rather
/// than in each member package.
File? findUpwards(String start, String relative) {
  String directory = p.absolute(start);
  while (true) {
    final candidate = File(p.join(directory, relative));
    if (candidate.existsSync()) {
      return candidate;
    }
    final String parent = p.dirname(directory);
    if (parent == directory) {
      return null;
    }
    directory = parent;
  }
}

/// [path] relative to [from], with `/` as separator on every platform - the
/// form globs, asset ids and reports use.
String posixRelative(String path, {required String from}) =>
    p.posix.joinAll(p.split(p.relative(path, from: from)));

/// The files under [root] that match one of [include] and none of
/// [exclude], as sorted paths relative to [root].
///
/// Directories that [exclude] rules out entirely are not entered, so a
/// `**/.dart_tool/**` keeps the walk out of the tool caches.
List<String> listFiles(
  String root,
  List<String> include,
  List<String> exclude,
) {
  final List<Glob> includes = [
    for (final pattern in include) Glob(pattern, context: p.posix),
  ];
  final List<Glob> excludes = [
    for (final pattern in exclude) Glob(pattern, context: p.posix),
  ];
  bool excluded(String path) => excludes.any((glob) => glob.matches(path));

  final files = <String>[];
  void visit(Directory directory) {
    final List<FileSystemEntity> entries = directory.listSync(
      followLinks: false,
    )..sort((a, b) => a.path.compareTo(b.path));
    for (final entry in entries) {
      final String relative = posixRelative(entry.path, from: root);
      final bool skipsDirectory = excluded('$relative/.inspectra');
      if (entry is Directory && !skipsDirectory) {
        visit(entry);
      }
      final bool selected =
          entry is File &&
          !excluded(relative) &&
          includes.any((glob) => glob.matches(relative));
      if (selected) {
        files.add(relative);
      }
    }
  }

  visit(Directory(root));
  return files;
}
