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

import 'package:inspectra/src/workspace/package_dependency_graph.dart';
import 'package:inspectra/src/workspace/workspace.dart';
import 'package:inspectra/src/workspace/workspace_member.dart';

/// The files at the workspace root whose change affects every package.
const _sharedFiles = <String>{
  'pubspec.yaml',
  'pubspec.lock',
  'inspectra.yaml',
  'analysis_options.yaml',
};

/// Finds the packages of [workspace] that the [changed] files, relative
/// to its root with `/` separators, affect: the packages containing them
/// and every package depending on those, development dependencies
/// included when [includeDev] is set. A change of a file every package
/// shares, such as the root `pubspec.lock`, affects all of them.
///
/// Returns the affected members in the order of the workspace.
List<WorkspaceMember> affectedPackages(
  Workspace workspace,
  Iterable<String> changed, {
  bool includeDev = true,
}) {
  final List<String> files = changed.toList();
  if (files.any(_sharedFiles.contains)) {
    return workspace.members;
  }
  final direct = <String>{
    for (final file in files) workspace.memberOf(file).name,
  };
  final Set<String> affected = PackageDependencyGraph.of(
    workspace,
    includeDev: includeDev,
  ).withDependents(direct);
  return <WorkspaceMember>[
    for (final WorkspaceMember member in workspace.members)
      if (affected.contains(member.name)) member,
  ];
}
