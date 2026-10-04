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

import 'dart:io';

import 'package:inspectra/src/host/host_platform.dart';
import 'package:inspectra/src/io/environment.dart';
import 'package:path/path.dart' as p;

/// Locates executables on the `PATH` and in additional directories.
///
/// The lookup mirrors what a shell does: every `PATH` entry is searched in
/// order and on Windows every extension listed in `PATHEXT` is tried, so that
/// `trivy` finds `trivy.exe`. Only regular files that are executable by the
/// current user are accepted.
final class ExecutableResolver {
  /// Creates a resolver reading `PATH` from [environment] for the given
  /// [host].
  const ExecutableResolver({required this.environment, required this.host});

  /// The environment providing `PATH` and `PATHEXT`.
  final Environment environment;

  /// The platform deciding the lookup rules.
  final HostPlatform host;

  /// The extensions tried on Windows when `PATHEXT` is not set.
  static const _defaultWindowsExtensions = <String>['.exe', '.cmd', '.bat'];

  /// The POSIX permission bits granting execute access to anyone.
  static const _anyExecuteBits = 0x49;

  /// Resolves [command] on the `PATH`, then in [extraDirectories].
  ///
  /// [command] may also be an absolute or relative path, which is accepted
  /// as is when it points at an executable file.
  ///
  /// Returns the absolute path of the first match, or `null`.
  String? resolve(String command, {List<String> extraDirectories = const []}) {
    if (p.isAbsolute(command) || command.contains(p.separator)) {
      return _executableOrNull(command);
    }
    final String separator = host.pathListSeparator;
    final directories = <String>[
      ...environment.pathEntries(separator),
      ...extraDirectories,
    ];
    final List<String> names = candidateNames(command);
    for (final directory in directories) {
      final String? match = _firstExecutable(directory, names);
      if (match != null) {
        return match;
      }
    }
    return null;
  }

  /// Returns the file names tried for [command] on this platform.
  ///
  /// On Windows these are the command with every `PATHEXT` extension
  /// followed by the bare command; elsewhere it is just the command.
  List<String> candidateNames(String command) {
    if (!host.isWindows) {
      return <String>[command];
    }
    final String? declared = environment['PATHEXT'];
    final List<String> extensions = declared == null
        ? _defaultWindowsExtensions
        : declared.split(';').where((e) => e.isNotEmpty).toList();
    final Iterable<String> withExtensions = extensions.map(
      (e) => '$command${e.toLowerCase()}',
    );
    return <String>[...withExtensions, command];
  }

  /// Searches [directory] for the first of [names] that is executable.
  ///
  /// Returns the absolute path of the match, or `null`.
  String? _firstExecutable(String directory, List<String> names) {
    for (final name in names) {
      final String? candidate = _executableOrNull(p.join(directory, name));
      if (candidate != null) {
        return candidate;
      }
    }
    return null;
  }

  /// Checks whether [path] is an executable regular file.
  ///
  /// Returns the absolute path when it is, otherwise `null`.
  String? _executableOrNull(String path) {
    final FileStat stat = FileStat.statSync(path);
    if (stat.type != FileSystemEntityType.file) {
      return null;
    }
    final bool executable =
        host.isWindows || (stat.mode & _anyExecuteBits) != 0;
    if (!executable) {
      return null;
    }
    return p.absolute(path);
  }
}
