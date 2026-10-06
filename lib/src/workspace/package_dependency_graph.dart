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

import 'package:inspectra/src/workspace/workspace.dart';
import 'package:inspectra/src/workspace/workspace_member.dart';

/// The dependencies between the packages of a workspace.
final class PackageDependencyGraph {
  /// Creates the graph whose [edges] map every package to the packages of
  /// the workspace it depends on.
  const PackageDependencyGraph(this.edges);

  /// Builds the graph of [workspace]; with [includeDev], development
  /// dependencies count as well.
  ///
  /// Returns the graph.
  factory PackageDependencyGraph.of(
    Workspace workspace, {
    bool includeDev = false,
  }) {
    final names = <String>{
      for (final WorkspaceMember member in workspace.members) member.name,
    };
    return PackageDependencyGraph(<String, List<String>>{
      for (final WorkspaceMember member in workspace.members)
        member.name: <String>{
          ...member.pubspec.dependencies.keys,
          if (includeDev) ...member.pubspec.devDependencies.keys,
        }.where(names.contains).toList()..sort(),
    });
  }

  /// The packages of the workspace each package depends on.
  final Map<String, List<String>> edges;

  /// Finds the dependency cycles with Tarjan's algorithm.
  ///
  /// Returns every group of packages that depend on each other, each in a
  /// stable order starting with its smallest name, as well as packages
  /// that depend on themselves.
  List<List<String>> cycles() {
    var counter = 0;
    final index = <String, int>{};
    final lowLink = <String, int>{};
    final stack = <String>[];
    final onStack = <String>{};
    final found = <List<String>>[];

    void connect(String node) {
      index[node] = counter;
      lowLink[node] = counter;
      counter++;
      stack.add(node);
      onStack.add(node);
      for (final String next in edges[node] ?? const <String>[]) {
        if (!index.containsKey(next)) {
          connect(next);
          lowLink[node] = _min(lowLink[node], lowLink[next]);
          continue;
        }
        if (onStack.contains(next)) {
          lowLink[node] = _min(lowLink[node], index[next]);
        }
      }
      if (lowLink[node] != index[node]) {
        return;
      }
      final component = <String>[];
      while (true) {
        final String member = stack.removeLast();
        onStack.remove(member);
        component.add(member);
        if (member == node) {
          break;
        }
      }
      final bool selfLoop =
          component.length == 1 &&
          (edges[node] ?? const <String>[]).contains(node);
      if (component.length > 1 || selfLoop) {
        found.add(component..sort());
      }
    }

    final List<String> nodes = edges.keys.toList()..sort();
    for (final node in nodes) {
      if (!index.containsKey(node)) {
        connect(node);
      }
    }
    return found..sort((a, b) => a.first.compareTo(b.first));
  }

  /// Finds the packages that depend on any of [changed], directly or
  /// through others.
  ///
  /// Returns [changed] and every package depending on them.
  Set<String> withDependents(Set<String> changed) {
    final affected = <String>{...changed};
    var grew = true;
    while (grew) {
      grew = false;
      for (final MapEntry(key: name, value: targets) in edges.entries) {
        if (!affected.contains(name) && targets.any(affected.contains)) {
          affected.add(name);
          grew = true;
        }
      }
    }
    return affected;
  }

  /// Returns the smaller of [a] and [b], which are set.
  static int _min(int? a, int? b) {
    final int left = a ?? 0;
    final int right = b ?? 0;
    return left < right ? left : right;
  }
}
