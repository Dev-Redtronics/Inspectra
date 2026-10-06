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

import 'package:inspectra/src/config/version_alignment.dart';
import 'package:inspectra/src/config/workspace_layer.dart';
import 'package:inspectra/src/config/workspace_policy_config.dart';
import 'package:inspectra/src/deps/version_bounds.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/model/source_location.dart';
import 'package:inspectra/src/pub/dependency_kind.dart';
import 'package:inspectra/src/pub/dependency_spec.dart';
import 'package:inspectra/src/report/snippet_sanitizer.dart';
import 'package:inspectra/src/workspace/package_dependency_graph.dart';
import 'package:inspectra/src/workspace/workspace.dart';
import 'package:inspectra/src/workspace/workspace_member.dart';
import 'package:pub_semver/pub_semver.dart';

/// Checks the packages of a pub workspace against the
/// `workspace_policy:` section: membership, aligned versions, SDK
/// constraints, dependency cycles and the layers of the architecture.
final class WorkspacePolicy {
  /// Creates the policy of [config].
  const WorkspacePolicy(this.config);

  /// The policy settings.
  final WorkspacePolicyConfig config;

  /// Checks [workspace].
  ///
  /// Returns the findings of the source [FindingSource.workspace].
  List<Finding> check(Workspace workspace) {
    final graph = PackageDependencyGraph.of(
      workspace,
      includeDev: config.includeDevDependencies,
    );
    return <Finding>[
      if (config.requireMembership) ..._membership(workspace),
      ..._alignment(workspace),
      if (config.sameSdk) ..._sdk(workspace),
      if (config.forbidCycles) ..._cycles(workspace, graph),
      ..._layers(workspace, graph),
    ];
  }

  /// Reports `workspace:` entries without a package, members that are not
  /// resolved by the workspace and packages that are not listed.
  Iterable<Finding> _membership(Workspace workspace) sync* {
    for (final (WorkspaceMember parent, String entry) in workspace.missing) {
      yield _finding(
        'WORKSPACE_MEMBER_MISSING',
        Severity.high,
        'The workspace entry $entry names no package',
        'No directory matching "$entry" has a pubspec.yaml, so "dart pub '
            'get" fails. Fix the entry or remove it.',
        parent.locator.topLevel('workspace'),
      );
    }
    for (final String path in workspace.unlisted) {
      yield _finding(
        'WORKSPACE_MEMBER_MISSING',
        Severity.high,
        'The package of $path is not listed in the workspace',
        'It declares resolution: workspace, but no workspace: list names '
            'its directory, so "dart pub get" fails. Add it to the '
            'workspace.',
        SourceLocation(path),
      );
    }
    for (final WorkspaceMember member in workspace.members.skip(1)) {
      if (!member.pubspec.isWorkspaceMember) {
        yield _finding(
          'WORKSPACE_RESOLUTION_MISSING',
          Severity.high,
          '${member.name} is listed but not resolved by the workspace',
          'Add "resolution: workspace" to its pubspec.yaml, so that it '
              'shares the workspace lockfile and the versions of every '
              'other package.',
          member.locator.topLevel('name'),
          package: member.name,
        );
      }
    }
  }

  /// Reports external dependencies whose constraints differ between the
  /// packages more than `align_versions` allows.
  Iterable<Finding> _alignment(Workspace workspace) sync* {
    if (config.alignVersions == VersionAlignment.off) {
      return;
    }
    final internal = <String>{
      for (final WorkspaceMember member in workspace.members) member.name,
    };
    final declarations = <String, List<(WorkspaceMember, String, String)>>{};
    for (final WorkspaceMember member in workspace.members) {
      for (final section in <String>['dependencies', 'dev_dependencies']) {
        final Map<String, DependencySpec> declared = section == 'dependencies'
            ? member.pubspec.dependencies
            : member.pubspec.devDependencies;
        for (final MapEntry(key: name, value: spec) in declared.entries) {
          final String? constraint = spec.constraint;
          final bool external =
              spec.kind == DependencyKind.hosted &&
              constraint != null &&
              !internal.contains(name);
          if (external) {
            declarations
                .putIfAbsent(name, () => <(WorkspaceMember, String, String)>[])
                .add((member, section, constraint));
          }
        }
      }
    }
    final List<String> names = declarations.keys.toList()..sort();
    for (final name in names) {
      final List<(WorkspaceMember, String, String)> uses =
          declarations[name] ?? const <(WorkspaceMember, String, String)>[];
      yield* config.alignVersions == VersionAlignment.exact
          ? _exact(name, uses)
          : _compatible(name, uses);
    }
  }

  /// Reports the declarations of [name] in [uses] that differ from the
  /// constraint most packages write.
  Iterable<Finding> _exact(
    String name,
    List<(WorkspaceMember, String, String)> uses,
  ) sync* {
    final counts = <String, int>{};
    for (final (_, _, String constraint) in uses) {
      counts[constraint] = (counts[constraint] ?? 0) + 1;
    }
    if (counts.length < 2) {
      return;
    }
    final String common =
        (counts.entries.toList()..sort((a, b) {
              final int byCount = b.value.compareTo(a.value);
              return byCount != 0 ? byCount : a.key.compareTo(b.key);
            }))
            .first
            .key;
    for (final (WorkspaceMember member, String section, String constraint)
        in uses) {
      if (constraint == common) {
        continue;
      }
      yield _finding(
        'WORKSPACE_VERSION_MISMATCH',
        Severity.medium,
        '${member.name} constrains $name as $constraint, the workspace as '
            '$common',
        'workspace_policy.align_versions is exact: every package writes '
            'the same constraint. ${_listing(uses)}',
        member.locator.entry(section, name),
        package: name,
        fix: common,
      );
    }
  }

  /// Reports [name] when the constraints of [uses] allow no common version.
  Iterable<Finding> _compatible(
    String name,
    List<(WorkspaceMember, String, String)> uses,
  ) sync* {
    VersionConstraint common = VersionConstraint.any;
    for (final (_, _, String constraint) in uses) {
      final VersionConstraint? parsed = parseConstraint(constraint);
      common = parsed == null ? common : common.intersect(parsed);
    }
    if (!common.isEmpty) {
      return;
    }
    final (WorkspaceMember member, String section, _) = uses.first;
    yield _finding(
      'WORKSPACE_VERSION_MISMATCH',
      Severity.medium,
      'The packages constrain $name to versions that do not overlap',
      'pub resolves one version of $name for the whole workspace, and no '
          'version satisfies every constraint. ${_listing(uses)}',
      member.locator.entry(section, name),
      package: name,
    );
  }

  /// Lists who declares which constraint in [uses], for a message.
  ///
  /// Returns a text such as `Declared: app ^1.0.0, core ^2.0.0.`.
  static String _listing(List<(WorkspaceMember, String, String)> uses) =>
      'Declared: ${uses.map((use) => '${use.$1.name} ${use.$3}').join(', ')}.';

  /// Reports packages whose SDK constraint differs from the root's.
  Iterable<Finding> _sdk(Workspace workspace) sync* {
    final String? expected = workspace.members.first.pubspec.sdkConstraint;
    for (final WorkspaceMember member in workspace.members.skip(1)) {
      final String? actual = member.pubspec.sdkConstraint;
      if (actual == expected) {
        continue;
      }
      yield _finding(
        'WORKSPACE_SDK_MISMATCH',
        Severity.medium,
        '${member.name} requires the SDK ${actual ?? 'unconstrained'}, the '
            'workspace ${expected ?? 'unconstrained'}',
        'workspace_policy.same_sdk asks every package for the SDK '
            'constraint of the root, so that all of them are tested with '
            'the same language version.',
        member.locator.entry('environment', 'sdk'),
        package: member.name,
        fix: expected,
      );
    }
  }

  /// Reports every group of packages that depend on each other.
  Iterable<Finding> _cycles(
    Workspace workspace,
    PackageDependencyGraph graph,
  ) sync* {
    for (final List<String> cycle in graph.cycles()) {
      final WorkspaceMember? first = workspace.named(cycle.first);
      yield _finding(
        'DEPENDENCY_CYCLE',
        Severity.high,
        'The packages ${cycle.join(', ')} depend on each other',
        'A cycle makes the packages one unit: none can be built, tested or '
            'released alone. Move what they share into a package they all '
            'depend on.',
        first?.locator.topLevel('name') ?? SourceLocation(cycle.first),
        package: cycle.first,
      );
    }
  }

  /// Reports packages outside every layer and dependencies the layers
  /// forbid.
  Iterable<Finding> _layers(
    Workspace workspace,
    PackageDependencyGraph graph,
  ) sync* {
    if (config.layers.isEmpty) {
      return;
    }
    final layerOf = <String, WorkspaceLayer>{};
    for (final WorkspaceMember member in workspace.members) {
      final WorkspaceLayer? layer = config.layers
          .where((candidate) => candidate.contains(member.path))
          .firstOrNull;
      if (layer != null) {
        layerOf[member.name] = layer;
        continue;
      }
      if (!member.isRoot) {
        yield _finding(
          'LAYER_UNASSIGNED',
          Severity.low,
          '${member.name} belongs to no layer',
          'No glob of workspace_policy.layers matches ${member.path}, so no '
              'layer rule applies to it. Add it to a layer.',
          member.locator.topLevel('name'),
          package: member.name,
        );
      }
    }
    for (final WorkspaceMember member in workspace.members) {
      final WorkspaceLayer? layer = layerOf[member.name];
      if (layer == null) {
        continue;
      }
      yield* _forbidden(member, layer);
      for (final String target
          in graph.edges[member.name] ?? const <String>[]) {
        final WorkspaceLayer? targetLayer = layerOf[target];
        if (targetLayer == null || target == member.name) {
          continue;
        }
        final String? reason = _violation(layer, targetLayer);
        if (reason != null) {
          yield _finding(
            'LAYER_VIOLATION',
            Severity.high,
            '${member.name} (${layer.name}) depends on $target '
                '(${targetLayer.name})',
            reason,
            _declaration(member, target),
            package: target,
          );
        }
      }
    }
  }

  /// Decides whether a package of [from] may depend on one of [to].
  ///
  /// Returns why it may not, or `null` when it may.
  static String? _violation(WorkspaceLayer from, WorkspaceLayer to) {
    if (from.name == to.name) {
      return from.isolated
          ? 'The packages of the layer ${from.name} are isolated and may not '
                'depend on each other. Move what they share into a lower '
                'layer.'
          : null;
    }
    final List<String>? allowed = from.mayDependOn;
    if (allowed == null || allowed.contains(to.name)) {
      return null;
    }
    final String list = allowed.isEmpty ? 'no other layer' : allowed.join(', ');
    return 'The layer ${from.name} may depend on $list only.';
  }

  /// Reports the dependencies of [member] that its [layer] forbids.
  Iterable<Finding> _forbidden(
    WorkspaceMember member,
    WorkspaceLayer layer,
  ) sync* {
    for (final String name in layer.forbiddenDependencies) {
      final bool declared =
          member.pubspec.dependencies.containsKey(name) ||
          (config.includeDevDependencies &&
              member.pubspec.devDependencies.containsKey(name));
      if (declared) {
        yield _finding(
          'FORBIDDEN_DEPENDENCY',
          Severity.high,
          '${member.name} (${layer.name}) depends on $name',
          'The layer ${layer.name} forbids $name, for example to keep it '
              'free of Flutter or of I/O.',
          _declaration(member, name),
          package: name,
        );
      }
    }
  }

  /// Locates the declaration of [name] in the pubspec of [member].
  ///
  /// Returns the location.
  static SourceLocation _declaration(WorkspaceMember member, String name) =>
      member.locator.entry(
        member.pubspec.dependencies.containsKey(name)
            ? 'dependencies'
            : 'dev_dependencies',
        name,
      );

  /// Creates a finding of the source [FindingSource.workspace].
  ///
  /// Returns the finding.
  static Finding _finding(
    String ruleId,
    Severity severity,
    String title,
    String description,
    SourceLocation location, {
    String? package,
    String? fix,
  }) => Finding(
    ruleId: ruleId,
    source: FindingSource.workspace,
    severity: severity,
    title: SnippetSanitizer.sanitize(title),
    description: SnippetSanitizer.escape(description),
    location: location,
    packageName: package,
    attributes: <String, Object?>{'fix': ?fix},
  );
}
