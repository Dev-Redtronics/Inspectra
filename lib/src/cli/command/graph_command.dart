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

import 'package:args/command_runner.dart';
import 'package:inspectra/src/cli/command_context.dart';
import 'package:inspectra/src/cli/config_bases.dart';
import 'package:inspectra/src/cli/exit_code.dart';
import 'package:inspectra/src/config/config_loader.dart';
import 'package:inspectra/src/config/config_overrides.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/pub/dependency_spec.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/pub/pubspec_parser.dart';
import 'package:inspectra/src/workspace/graph_format.dart';
import 'package:inspectra/src/workspace/graph_renderer.dart';
import 'package:inspectra/src/workspace/package_dependency_graph.dart';
import 'package:inspectra/src/workspace/workspace.dart';
import 'package:inspectra/src/workspace/workspace_member.dart';
import 'package:path/path.dart' as p;

/// `inspectra graph`: prints the dependencies between the packages of a pub
/// workspace, grouped by the layers of `workspace_policy`, or the direct
/// dependencies of a single package.
final class GraphCommand extends Command<int> {
  /// Creates the command with its `--format`, `--include-dev` and
  /// `--external` options.
  GraphCommand(this.context) {
    argParser
      ..addOption(
        'format',
        abbr: 'f',
        help: 'Output format.',
        allowed: <String>[for (final format in GraphFormat.values) format.id],
        defaultsTo: GraphFormat.text.id,
      )
      ..addFlag(
        'include-dev',
        negatable: false,
        help: 'Also draw dev_dependencies.',
      )
      ..addFlag(
        'external',
        negatable: false,
        help: 'Also draw the dependencies outside the workspace.',
      );
  }

  /// The outside world.
  final CommandContext context;

  /// The command name.
  @override
  String get name => 'graph';

  /// The one line description.
  @override
  String get description =>
      'Print the dependency graph of a pub workspace as text, DOT, Mermaid '
      'or JSON.';

  /// The positional arguments.
  @override
  String get invocation => 'inspectra graph [directory] [options]';

  /// Prints the usage to standard output of the [context].
  @override
  void printUsage() => context.out.writeln(usage);

  /// Prints the graph.
  ///
  /// Returns `0`; `65` for a malformed pubspec or configuration or a
  /// directory without `pubspec.yaml`.
  @override
  Future<int> run() async {
    final directory = globalResults?['directory'] as String?;
    final String root = p.normalize(
      p.join(
        context.workingDirectory,
        directory ?? '.',
        argResults?.rest.firstOrNull ?? '.',
      ),
    );
    final dev = argResults?['include-dev'] == true;
    final GraphFormat format = GraphFormat.values.firstWhere(
      (value) => value.id == argResults?['format'],
    );
    try {
      final Workspace? workspace = Workspace.load(root);
      final (Map<String, String?>, Map<String, List<String>>) graph =
          workspace == null
          ? _package(root, dev: dev)
          : _workspace(
              workspace,
              _config(root),
              dev: dev,
              external: argResults?['external'] == true,
            );
      context.out.write(renderGraph(format, nodes: graph.$1, edges: graph.$2));
      return ExitCode.success.code;
    } on InspectraConfigException catch (error) {
      context.err.writeln('error: $error');
      return ExitCode.dataError.code;
    } on InspectraException catch (error) {
      context.err.writeln('error: ${error.message}');
      return ExitCode.of(error).code;
    }
  }

  /// Reads the configuration of the workspace root [root].
  ///
  /// Returns the configuration.
  ///
  /// Throws an [InspectraConfigException] when it is invalid.
  InspectraConfig _config(String root) => loadConfig(
    root,
    overrides: ConfigOverrides(environment: context.environment),
    requirePubspec: false,
    cacheRoot: cacheRootOf(context),
  );

  /// Builds the graph of [workspace]: its packages with their layers from
  /// [config], development dependencies with [dev] and packages outside
  /// the workspace with [external].
  ///
  /// Returns the nodes and edges.
  static (Map<String, String?>, Map<String, List<String>>) _workspace(
    Workspace workspace,
    InspectraConfig config, {
    required bool dev,
    required bool external,
  }) {
    final graph = PackageDependencyGraph.of(workspace, includeDev: dev);
    final nodes = <String, String?>{
      for (final WorkspaceMember member in workspace.members)
        member.name: config.workspacePolicy.layers
            .where((layer) => layer.contains(member.path))
            .firstOrNull
            ?.name,
    };
    final edges = <String, List<String>>{
      for (final WorkspaceMember member in workspace.members)
        member.name: <String>[
          ...graph.edges[member.name] ?? const <String>[],
          if (external)
            ..._declared(
              member.pubspec,
              dev: dev,
            ).where((name) => !nodes.containsKey(name)),
        ],
    };
    return (nodes, edges);
  }

  /// Builds the graph of the single package in [root]: the package and
  /// its direct dependencies, development dependencies with [dev].
  ///
  /// Returns the nodes and edges.
  ///
  /// Throws an [InvalidInputException] without a readable `pubspec.yaml`.
  static (Map<String, String?>, Map<String, List<String>>) _package(
    String root, {
    required bool dev,
  }) {
    final file = File(p.join(root, 'pubspec.yaml'));
    if (!file.existsSync()) {
      throw InvalidInputException('No pubspec.yaml found in $root.');
    }
    final Pubspec pubspec = const PubspecParser().parse(
      file.readAsStringSync(),
      path: 'pubspec.yaml',
    );
    final String name = pubspec.name ?? p.basename(root);
    return (
      <String, String?>{name: null},
      <String, List<String>>{name: _declared(pubspec, dev: dev)},
    );
  }

  /// Lists the dependencies [pubspec] declares, development dependencies
  /// with [dev], without SDK packages.
  ///
  /// Returns the sorted names.
  static List<String> _declared(Pubspec pubspec, {required bool dev}) =>
      <String>{
        for (final MapEntry<String, DependencySpec> entry
            in <MapEntry<String, DependencySpec>>[
              ...pubspec.dependencies.entries,
              if (dev) ...pubspec.devDependencies.entries,
            ])
          if (entry.value.sdk == null) entry.key,
      }.toList()..sort();
}
