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

import 'dart:convert';

import 'package:inspectra/src/workspace/graph_format.dart';

/// Renders the dependency graph of a package or workspace: [nodes] maps
/// every package to its layer, `null` for none, and [edges] maps every
/// package to the packages it depends on, which may be packages outside
/// [nodes].
///
/// Returns the text in [format], ending with a line break.
String renderGraph(
  GraphFormat format, {
  required Map<String, String?> nodes,
  required Map<String, List<String>> edges,
}) => switch (format) {
  GraphFormat.text => _text(nodes, edges),
  GraphFormat.dot => _dot(nodes, edges),
  GraphFormat.mermaid => _mermaid(nodes, edges),
  GraphFormat.json => _json(nodes, edges),
};

/// Renders JSON with `nodes`, each with its `layer`, and `edges`, marked
/// `external` when they leave the packages of [nodes].
///
/// Returns the text.
String _json(Map<String, String?> nodes, Map<String, List<String>> edges) {
  final document = <String, Object?>{
    'nodes': <Map<String, Object?>>[
      for (final MapEntry(key: name, value: layer) in nodes.entries)
        <String, Object?>{'name': name, 'layer': layer},
    ],
    'edges': <Map<String, Object?>>[
      for (final MapEntry(key: from, value: targets) in edges.entries)
        for (final to in targets)
          <String, Object?>{
            'from': from,
            'to': to,
            'external': !nodes.containsKey(to),
          },
    ],
  };
  return '${const JsonEncoder.withIndent('  ').convert(document)}\n';
}

/// Renders one line per package.
///
/// Returns the text.
String _text(Map<String, String?> nodes, Map<String, List<String>> edges) {
  final out = StringBuffer();
  for (final MapEntry(key: name, value: layer) in nodes.entries) {
    final label = layer == null ? name : '$name [$layer]';
    final List<String> targets = edges[name] ?? const <String>[];
    out.writeln(targets.isEmpty ? label : '$label -> ${targets.join(', ')}');
  }
  return out.toString();
}

/// Renders Graphviz DOT with a cluster per layer.
///
/// Returns the text.
String _dot(Map<String, String?> nodes, Map<String, List<String>> edges) {
  final out = StringBuffer()
    ..writeln('digraph dependencies {')
    ..writeln('  rankdir=LR;')
    ..writeln('  node [shape=box];');
  final List<String> layers = _layers(nodes);
  for (var index = 0; index < layers.length; index++) {
    out
      ..writeln('  subgraph cluster_$index {')
      ..writeln('    label=${_quote(layers[index])};');
    for (final MapEntry(key: name, value: layer) in nodes.entries) {
      if (layer == layers[index]) {
        out.writeln('    ${_quote(name)};');
      }
    }
    out.writeln('  }');
  }
  for (final MapEntry(key: name, value: layer) in nodes.entries) {
    if (layer == null) {
      out.writeln('  ${_quote(name)};');
    }
  }
  for (final MapEntry(key: from, value: targets) in edges.entries) {
    for (final to in targets) {
      final style = nodes.containsKey(to) ? '' : ' [style=dashed]';
      out.writeln('  ${_quote(from)} -> ${_quote(to)}$style;');
    }
  }
  out.writeln('}');
  return out.toString();
}

/// Renders a Mermaid flowchart with a subgraph per layer.
///
/// Returns the text.
String _mermaid(Map<String, String?> nodes, Map<String, List<String>> edges) {
  final out = StringBuffer()..writeln('flowchart LR');
  final List<String> layers = _layers(nodes);
  for (var index = 0; index < layers.length; index++) {
    out.writeln('  subgraph layer$index [${_label(layers[index])}]');
    for (final MapEntry(key: name, value: layer) in nodes.entries) {
      if (layer == layers[index]) {
        out.writeln('    ${_id(name)}[${_label(name)}]');
      }
    }
    out.writeln('  end');
  }
  for (final MapEntry(key: name, value: layer) in nodes.entries) {
    if (layer == null) {
      out.writeln('  ${_id(name)}[${_label(name)}]');
    }
  }
  for (final MapEntry(key: from, value: targets) in edges.entries) {
    for (final to in targets) {
      final arrow = nodes.containsKey(to) ? '-->' : '-.->';
      out.writeln('  ${_id(from)} $arrow ${_id(to)}');
    }
  }
  return out.toString();
}

/// Returns the layers of [nodes] in their order of appearance.
List<String> _layers(Map<String, String?> nodes) =>
    <String>{...nodes.values.nonNulls}.toList();

/// Quotes [text] for DOT.
String _quote(String text) =>
    '"${text.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

/// Turns [name] into a Mermaid node id.
String _id(String name) => name.replaceAll(RegExp('[^A-Za-z0-9_]'), '_');

/// Quotes [text] as a Mermaid label.
String _label(String text) => '"${text.replaceAll('"', "'")}"';
