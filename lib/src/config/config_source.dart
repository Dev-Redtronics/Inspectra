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

import 'package:yaml/yaml.dart';

import '../io/environment.dart';
import '../model/inspectra_exception.dart';

/// A layered, typed view of every configuration input.
///
/// A configuration key such as `trivy.version` is resolved from, in order of
/// precedence:
///
/// 1. command line overrides (`--set trivy.version=0.74.0` or a dedicated
///    flag such as `--trivy-version`);
/// 2. the environment variable derived from the key, `INSPECTRA_` followed by
///    the upper snake case path (`INSPECTRA_TRIVY_VERSION`);
/// 3. the configuration file (`trivy: { version: 0.74.0 }`).
///
/// Every key read through this class is recorded, which lets
/// [ensureNoUnknownKeys] reject typos such as `trivy.verison` instead of
/// silently ignoring them.
final class ConfigSource {
  /// Creates a source from a parsed configuration [document] named
  /// [documentName] in messages, the [environment] and the command line
  /// [overrides] keyed by dotted path.
  ConfigSource({
    required Map<String, Object?> document,
    required this.documentName,
    required this.environment,
    required this.overrides,
  }) : _document = document;

  /// Parses YAML [content] into a source.
  ///
  /// [documentName] identifies the file in error messages.
  ///
  /// Returns the source.
  ///
  /// Throws an [InvalidInputException] when [content] is not a YAML mapping.
  factory ConfigSource.fromYaml(
    String content, {
    required String documentName,
    required Environment environment,
    required Map<String, String> overrides,
  }) {
    final Object? parsed;
    try {
      parsed = loadYaml(content);
    } on YamlException catch (error) {
      throw InvalidInputException(
        '$documentName is not valid YAML: ${error.message}',
      );
    }
    final plain = toPlainValue(parsed);
    if (plain != null && plain is! Map<String, Object?>) {
      throw InvalidInputException(
        '$documentName must contain a YAML mapping at its top level.',
      );
    }
    return ConfigSource(
      document: plain is Map<String, Object?> ? plain : <String, Object?>{},
      documentName: documentName,
      environment: environment,
      overrides: overrides,
    );
  }

  /// The parsed configuration file.
  final Map<String, Object?> _document;

  /// The file name used in messages.
  final String documentName;

  /// The environment providing `INSPECTRA_*` variables.
  final Environment environment;

  /// Command line overrides keyed by dotted path.
  final Map<String, String> overrides;

  /// Every dotted path that has been read.
  final Set<String> _knownPaths = <String>{};

  /// Converts parsed YAML nodes into plain Dart maps, lists and scalars.
  ///
  /// Returns the converted value; map keys are converted to strings.
  static Object? toPlainValue(Object? value) {
    if (value is YamlMap) {
      return <String, Object?>{
        for (final entry in value.entries)
          '${entry.key}': toPlainValue(entry.value),
      };
    }
    if (value is YamlList) {
      return value.map(toPlainValue).toList();
    }
    return value;
  }

  /// Returns the environment variable name derived from the dotted [path],
  /// for example `INSPECTRA_TRIVY_DOWNLOAD_BASE_URL` for
  /// `trivy.downloadBaseUrl`.
  static String environmentName(String path) {
    final segments = path.split('.').map(_upperSnake);
    return 'INSPECTRA_${segments.join('_')}';
  }

  /// Converts a camel case [segment] to upper snake case.
  ///
  /// Returns the converted segment, for example `DOWNLOAD_BASE_URL`.
  static String _upperSnake(String segment) {
    final snake = segment.replaceAllMapped(
      RegExp('([a-z0-9])([A-Z])'),
      (match) => '${match[1]}_${match[2]}',
    );
    return snake.toUpperCase();
  }

  /// Resolves the raw value of [path] from the highest precedence layer.
  ///
  /// Returns the value and a description of its origin, or `null` when no
  /// layer defines the key.
  (Object?, String)? _resolve(String path) {
    _knownPaths.add(path);
    final override = overrides[path];
    if (override != null) {
      return (override, 'the command line option for "$path"');
    }
    final variable = environmentName(path);
    final fromEnvironment = environment[variable];
    if (fromEnvironment != null) {
      return (fromEnvironment, 'the environment variable $variable');
    }
    final fromFile = _fileValue(path);
    if (fromFile == null) {
      return null;
    }
    return (fromFile, '"$path" in $documentName');
  }

  /// Walks the configuration file along the dotted [path].
  ///
  /// Returns the value stored there, or `null` when absent.
  Object? _fileValue(String path) {
    Object? current = _document;
    for (final segment in path.split('.')) {
      if (current is! Map<String, Object?>) {
        return null;
      }
      current = current[segment];
    }
    return current;
  }

  /// Builds the error for a value of the wrong shape.
  ///
  /// Returns the exception to throw.
  InvalidInputException _invalid(String origin, String expected, Object? got) {
    return InvalidInputException(
      'Invalid configuration value from $origin: expected $expected but got '
      '"$got".',
    );
  }

  /// Reads [path] as a non-blank string.
  ///
  /// Returns the value, or `null` when the key is not set.
  ///
  /// Throws an [InvalidInputException] for non-scalar values.
  String? string(String path) {
    final resolved = _resolve(path);
    if (resolved == null) {
      return null;
    }
    final (value, origin) = resolved;
    if (value is Map || value is List) {
      throw _invalid(origin, 'a single value', value);
    }
    final text = '$value'.trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  /// Reads [path] as a boolean; `true`, `false`, `yes`, `no`, `1` and `0`
  /// are accepted in any case.
  ///
  /// Returns the value, or `null` when the key is not set.
  ///
  /// Throws an [InvalidInputException] for anything else.
  bool? boolean(String path) {
    final resolved = _resolve(path);
    if (resolved == null) {
      return null;
    }
    final (value, origin) = resolved;
    if (value is bool) {
      return value;
    }
    final text = '$value'.trim().toLowerCase();
    if (const <String>{'true', 'yes', '1', 'on'}.contains(text)) {
      return true;
    }
    if (const <String>{'false', 'no', '0', 'off'}.contains(text)) {
      return false;
    }
    throw _invalid(origin, 'true or false', value);
  }

  /// Reads [path] as an integer of at least [min].
  ///
  /// Returns the value, or `null` when the key is not set.
  ///
  /// Throws an [InvalidInputException] for non-integers or values below
  /// [min].
  int? integer(String path, {int min = 0}) {
    final resolved = _resolve(path);
    if (resolved == null) {
      return null;
    }
    final (value, origin) = resolved;
    final parsed = value is int ? value : int.tryParse('$value'.trim());
    if (parsed == null || parsed < min) {
      throw _invalid(origin, 'an integer of at least $min', value);
    }
    return parsed;
  }

  /// Reads [path] as a number between [min] and [max].
  ///
  /// Returns the value, or `null` when the key is not set.
  ///
  /// Throws an [InvalidInputException] for non-numbers or values out of
  /// range.
  double? decimal(String path, {double min = 0, double max = 1}) {
    final resolved = _resolve(path);
    if (resolved == null) {
      return null;
    }
    final (value, origin) = resolved;
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    if (parsed == null || parsed < min || parsed > max) {
      throw _invalid(origin, 'a number between $min and $max', value);
    }
    return parsed;
  }

  /// Reads [path] as a duration such as `500ms`, `30s`, `10m` or `1h`; a
  /// bare number means seconds.
  ///
  /// Returns the value, or `null` when the key is not set.
  ///
  /// Throws an [InvalidInputException] for malformed durations.
  Duration? duration(String path) {
    final resolved = _resolve(path);
    if (resolved == null) {
      return null;
    }
    final (value, origin) = resolved;
    final match = RegExp(r'^(\d+)\s*(ms|s|m|h)?$').firstMatch('$value'.trim());
    if (match == null) {
      throw _invalid(origin, 'a duration such as 30s, 10m or 1h', value);
    }
    final amount = int.parse(match[1] ?? '0');
    final unit = match[2] ?? 's';
    const multipliers = <String, int>{
      'ms': 1,
      's': 1000,
      'm': 60 * 1000,
      'h': 60 * 60 * 1000,
    };
    return Duration(milliseconds: amount * (multipliers[unit] ?? 1000));
  }

  /// Reads [path] as a list of strings; on the command line and in the
  /// environment the list is comma separated.
  ///
  /// Returns the list, or `null` when the key is not set.
  ///
  /// Throws an [InvalidInputException] for nested structures.
  List<String>? stringList(String path) {
    final resolved = _resolve(path);
    if (resolved == null) {
      return null;
    }
    final (value, origin) = resolved;
    if (value is Map) {
      throw _invalid(origin, 'a list of values', value);
    }
    final items = value is List ? value.map((e) => '$e') : '$value'.split(',');
    final trimmed = items.map((item) => item.trim());
    return trimmed.where((item) => item.isNotEmpty).toList();
  }

  /// Reads [path] as one of the keys of [options].
  ///
  /// Returns the mapped value, or `null` when the key is not set.
  ///
  /// Throws an [InvalidInputException] when the value is not an option.
  T? choice<T>(String path, Map<String, T> options) {
    final text = string(path);
    if (text == null) {
      return null;
    }
    final selected = options[text.toLowerCase()];
    if (selected == null) {
      final origin = _resolve(path)?.$2 ?? path;
      throw _invalid(origin, 'one of ${options.keys.join(', ')}', text);
    }
    return selected;
  }

  /// Reads the raw file value of [path] without layering, for structured
  /// values such as the `ignore:` list that only the file can express.
  ///
  /// Returns the raw value, or `null` when absent.
  Object? structured(String path) {
    _knownPaths.add(path);
    return _fileValue(path);
  }

  /// Rejects every file key and override that was never read.
  ///
  /// Must be called after the whole configuration has been read.
  ///
  /// Throws an [InvalidInputException] naming the first unknown key.
  void ensureNoUnknownKeys() {
    for (final path in overrides.keys) {
      if (!_knownPaths.contains(path)) {
        throw InvalidInputException(
          'Unknown configuration key "$path" given on the command line.',
        );
      }
    }
    _checkMap(_document, '');
  }

  /// Recursively checks that every key below [map] at [prefix] is known.
  ///
  /// Throws an [InvalidInputException] for the first unknown key.
  void _checkMap(Map<String, Object?> map, String prefix) {
    for (final entry in map.entries) {
      final path = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      if (_knownPaths.contains(path)) {
        continue;
      }
      final isSection = _knownPaths.any((known) => known.startsWith('$path.'));
      final value = entry.value;
      if (isSection && value is Map<String, Object?>) {
        _checkMap(value, path);
        continue;
      }
      if (isSection) {
        throw InvalidInputException(
          '"$path" in $documentName must be a mapping of settings.',
        );
      }
      throw InvalidInputException(
        'Unknown configuration key "$path" in $documentName.',
      );
    }
  }
}
