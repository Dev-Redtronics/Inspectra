import 'dart:io';

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
