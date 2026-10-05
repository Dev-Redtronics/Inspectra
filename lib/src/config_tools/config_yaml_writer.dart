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

import 'package:inspectra/src/config/config_entry.dart';
import 'package:inspectra/src/config/config_origin.dart';

/// The column at which the comments of `config show` start, as in
/// `inspectra.example.yaml`.
const commentColumn = 37;

/// Words that YAML reads as something other than text.
const _reservedWords = <String>{
  'true',
  'false',
  'yes',
  'no',
  'on',
  'off',
  'null',
  '~',
};

/// A text that YAML reads as plain text without quotes.
final _plain = RegExp(r'^[A-Za-z0-9_./][A-Za-z0-9_./:@+-]*$');

/// Writes [entries] as the YAML of an `inspectra.yaml`, with nested
/// sections; an option without a value is a commented out `# key:` line.
///
/// With [explain], every option ends with a comment that tells where its
/// value comes from; [source] names the configuration file of values from
/// the file.
///
/// Returns the YAML text with a final line break, or an empty text without
/// entries.
String writeConfigYaml(
  List<ConfigEntry> entries, {
  bool explain = false,
  String? source,
}) {
  final root = <String, Object>{};
  for (final entry in entries) {
    final List<String> parts = entry.key.split('.');
    var node = root;
    for (final String part in parts.take(parts.length - 1)) {
      final Object child = node.putIfAbsent(part, () => <String, Object>{});
      node = child is Map<String, Object> ? child : <String, Object>{};
    }
    node[parts.last] = entry;
  }
  final lines = <String>[];
  _writeMap(root, 0, lines, explain: explain, source: source);
  return lines.isEmpty ? '' : '${lines.join('\n')}\n';
}

/// Describes where the value of [entry] comes from; [source] names the
/// configuration file.
///
/// Returns a text such as `inspectra.yaml:12` or
/// `environment variable INSPECTRA_TRIVY_VERSION`.
String describeOrigin(ConfigEntry entry, {String? source}) {
  if (entry.value == null) {
    return 'unset';
  }
  return switch (entry.origin) {
    ConfigOrigin.defaults => 'default',
    ConfigOrigin.file => _fileOrigin(entry, source),
    ConfigOrigin.environment => 'environment variable ${entry.variable}',
    ConfigOrigin.commandLine => 'command line',
  };
}

/// Describes the place of [entry] in its base or the configuration file
/// [source].
///
/// Returns the file with the line, when known.
String _fileOrigin(ConfigEntry entry, String? source) {
  final String file = entry.file ?? source ?? 'configuration file';
  final int? line = entry.line;
  return line == null ? file : '$file:$line';
}

/// Writes the mapping [node] at [depth] into [lines].
void _writeMap(
  Map<String, Object> node,
  int depth,
  List<String> lines, {
  required bool explain,
  required String? source,
}) {
  final String indent = '  ' * depth;
  for (final MapEntry<String, Object> child in node.entries) {
    final Object value = child.value;
    if (value is ConfigEntry) {
      _writeEntry(
        child.key,
        value,
        indent,
        lines,
        explain: explain,
        source: source,
      );
      continue;
    }
    if (value is Map<String, Object>) {
      lines.add('$indent${child.key}:');
      _writeMap(value, depth + 1, lines, explain: explain, source: source);
    }
  }
}

/// Writes the option [key] with its [entry] at [indent] into [lines].
void _writeEntry(
  String key,
  ConfigEntry entry,
  String indent,
  List<String> lines, {
  required bool explain,
  required String? source,
}) {
  final String comment = explain ? describeOrigin(entry, source: source) : '';
  final Object? value = entry.value;
  if (value == null) {
    lines.add(_withComment('$indent# $key:', comment));
    return;
  }
  final bool isBlockList =
      value is List<Object?> &&
      value.isNotEmpty &&
      value.any((item) => item is Map);
  if (!isBlockList) {
    lines.add(_withComment('$indent$key: ${_flow(value)}', comment));
    return;
  }
  lines.add(_withComment('$indent$key:', comment));
  for (final Object? item in value) {
    _writeBlockItem(item, '$indent  ', lines);
  }
}

/// Writes one [item] of a block list at [indent] into [lines].
void _writeBlockItem(Object? item, String indent, List<String> lines) {
  if (item is! Map<String, Object?>) {
    lines.add('$indent- ${_flow(item)}');
    return;
  }
  var first = true;
  for (final MapEntry<String, Object?> field in item.entries) {
    final marker = first ? '- ' : '  ';
    lines.add('$indent$marker${field.key}: ${_flow(field.value)}');
    first = false;
  }
}

/// Appends [comment] to [line] at the [commentColumn].
///
/// Returns the line, unchanged without a comment.
String _withComment(String line, String comment) {
  if (comment.isEmpty) {
    return line;
  }
  final String padded = line.length < commentColumn
      ? line.padRight(commentColumn)
      : '$line ';
  return '$padded# $comment';
}

/// Writes [value] in YAML flow style.
///
/// Returns the scalar, `[a, b]` list or `{a: b}` mapping.
String _flow(Object? value) {
  if (value == null || value is bool || value is num) {
    return '$value';
  }
  if (value is List<Object?>) {
    return '[${value.map(_flow).join(', ')}]';
  }
  if (value is Map<Object?, Object?>) {
    return '{${value.entries.map(_flowField).join(', ')}}';
  }
  return quoteYaml('$value');
}

/// Writes one [field] of a flow mapping.
///
/// Returns `key: value`.
String _flowField(MapEntry<Object?, Object?> field) =>
    '${quoteYaml('${field.key}')}: ${_flow(field.value)}';

/// Quotes [text] for YAML when it would not read back as the same text.
///
/// Returns [text] itself, or [text] in single quotes with quotes doubled.
String quoteYaml(String text) {
  final bool isPlain =
      _plain.hasMatch(text) &&
      !_reservedWords.contains(text.toLowerCase()) &&
      num.tryParse(text) == null;
  if (isPlain) {
    return text;
  }
  return "'${text.replaceAll("'", "''")}'";
}
