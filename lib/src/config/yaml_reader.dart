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

import 'package:inspectra/src/config/config_overrides.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:yaml/yaml.dart';

/// A typed, strict and layered view on one YAML mapping of the
/// configuration.
///
/// Every key that is read is remembered, and [ensureFullyRead] rejects any
/// key that was not, so that a misspelled option fails loudly instead of
/// being ignored. Values are taken from the [ConfigOverrides] first, which
/// layers command line overrides and `INSPECTRA_*` environment variables on
/// top of the file. Overridden values are text and are converted to the type
/// the option expects; lists are comma separated.
final class YamlReader {
  /// Wraps [node], which lives at the dotted [path] in the configuration,
  /// with the shared [overrides].
  ///
  /// Throws an [InspectraConfigException] when [node] is neither `null` nor
  /// a mapping.
  ///
  /// [keyPath] is the logical path used for overrides; it differs from
  /// [path] for the `inspectra:` section of `pubspec.yaml`, whose keys are
  /// shown as `inspectra.trivy.mode` but overridden as `trivy.mode`.
  YamlReader(
    Object? node,
    this.path, {
    ConfigOverrides? overrides,
    String? keyPath,
  }) : _map = _asMap(node, path),
       keyPath = keyPath ?? path,
       overrides = overrides ?? ConfigOverrides.none();

  /// The dotted path of this mapping, empty for the root.
  final String path;

  /// The logical dotted path of this mapping, used to look up overrides.
  final String keyPath;

  /// The overrides shared by every reader of one configuration.
  final ConfigOverrides overrides;

  /// The wrapped mapping.
  final Map<Object?, Object?> _map;

  /// The keys that have been read.
  final _read = <String>{};

  /// Converts [node] into a mapping.
  ///
  /// Returns an empty mapping for `null`.
  ///
  /// Throws an [InspectraConfigException] for anything but a mapping.
  static Map<Object?, Object?> _asMap(Object? node, String path) {
    if (node == null) {
      return const <Object?, Object?>{};
    }
    if (node is Map) {
      return node;
    }
    throw InspectraConfigException(
      path,
      'expected a mapping, got ${_describe(node)}.',
    );
  }

  /// Returns the dotted path of the child [key].
  String _child(String key) => path.isEmpty ? key : '$path.$key';

  /// Returns the logical dotted path of the child [key].
  String _childKey(String key) => keyPath.isEmpty ? key : '$keyPath.$key';

  /// Marks [key] as read and returns its override, if any.
  ///
  /// Returns the raw override text, or `null` when the key is not
  /// overridden.
  String? _override(String key) {
    _read.add(key);
    return overrides.lookup(_childKey(key))?.$1;
  }

  /// Marks [key] as read and returns its value in the file.
  ///
  /// Returns the value, or `null` when absent.
  Object? _fileValue(String key) {
    _read.add(key);
    final Object? value = _map[key];
    return value is YamlNode ? value.value : value;
  }

  /// Builds the error for a value at [key] that is not [expected].
  ///
  /// Returns the exception to throw.
  InspectraConfigException _invalid(String key, String expected, Object? got) =>
      InspectraConfigException(
        _child(key),
        'expected $expected, got ${_describe(got)}.',
      );

  /// Returns the nested mapping at [key], empty when absent. Sections are
  /// never overridden as a whole.
  YamlReader section(String key) {
    _read.add(key);
    return YamlReader(
      _map[key],
      _child(key),
      overrides: overrides,
      keyPath: _childKey(key),
    );
  }

  /// Returns the raw value at [key] for structured options, such as the
  /// `ignore` list, that only the file can express.
  Object? structured(String key) => _fileValue(key);

  /// Returns the boolean at [key], or [fallback] when absent.
  ///
  /// Throws an [InspectraConfigException] for anything but a boolean.
  bool boolean(String key, {required bool fallback}) {
    final String? override = _override(key)?.trim().toLowerCase();
    if (override != null) {
      const truthy = <String>{'true', 'yes', '1', 'on'};
      const falsy = <String>{'false', 'no', '0', 'off'};
      if (truthy.contains(override)) {
        return true;
      }
      if (falsy.contains(override)) {
        return false;
      }
      throw _invalid(key, 'true or false', override);
    }
    final Object? value = _fileValue(key);
    if (value == null) {
      return fallback;
    }
    if (value is bool) {
      return value;
    }
    throw _invalid(key, 'true or false', value);
  }

  /// Returns the string at [key], or [fallback] when absent.
  ///
  /// Throws an [InspectraConfigException] for anything but a non-empty
  /// string.
  String string(String key, {required String fallback}) =>
      optionalString(key) ?? fallback;

  /// Returns the string at [key], or `null` when absent. Numbers in the
  /// file are accepted as their text, so `version: 0.75` reads as `0.75`.
  ///
  /// Throws an [InspectraConfigException] for anything but a non-empty
  /// scalar.
  String? optionalString(String key) {
    final String? override = _override(key)?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }
    final Object? value = _fileValue(key);
    if (value == null) {
      return null;
    }
    final bool isScalar = value is String || value is num;
    if (isScalar && '$value'.isNotEmpty) {
      return '$value';
    }
    throw _invalid(key, 'a non-empty string', value);
  }

  /// Returns the number at [key] between [min] and [max], or `null` when
  /// absent.
  ///
  /// Throws an [InspectraConfigException] for anything else.
  double? optionalNumber(
    String key, {
    required double min,
    required double max,
  }) {
    final String? override = _override(key);
    final Object? value = override == null
        ? _fileValue(key)
        : double.tryParse(override.trim()) ?? override;
    if (value == null) {
      return null;
    }
    if (value is num && value >= min && value <= max) {
      return value.toDouble();
    }
    throw _invalid(key, 'a number between $min and $max', value);
  }

  /// Returns the whole number at [key] between [min] and [max], or `null`
  /// when absent.
  ///
  /// Throws an [InspectraConfigException] for anything else.
  int? optionalInt(String key, {required int min, required int max}) {
    final String? override = _override(key);
    final Object? value = override == null
        ? _fileValue(key)
        : int.tryParse(override.trim()) ?? override;
    if (value == null) {
      return null;
    }
    if (value is int && value >= min && value <= max) {
      return value;
    }
    throw _invalid(key, 'a whole number between $min and $max', value);
  }

  /// Returns the duration at [key], written as `500ms`, `30s`, `10m` or `1h`
  /// (a bare number means seconds), or [fallback] when absent.
  ///
  /// Throws an [InspectraConfigException] for malformed durations.
  Duration duration(String key, {required Duration fallback}) {
    final String? override = _override(key);
    final Object? value = override ?? _fileValue(key);
    if (value == null) {
      return fallback;
    }
    final RegExpMatch? match = RegExp(r'^(\d+)\s*(ms|s|m|h)?$')
        .firstMatch('$value'.trim());
    if (match == null) {
      throw _invalid(key, 'a duration such as 30s, 10m or 1h', value);
    }
    const milliseconds = <String, int>{
      'ms': 1,
      's': 1000,
      'm': 60 * 1000,
      'h': 60 * 60 * 1000,
    };
    final int amount = int.parse(match[1] ?? '0');
    return Duration(
      milliseconds: amount * (milliseconds[match[2] ?? 's'] ?? 1),
    );
  }

  /// Returns the list of strings at [key], or [fallback] when absent. An
  /// override is a comma separated list.
  ///
  /// Throws an [InspectraConfigException] for anything but a list of
  /// non-empty strings.
  List<String> strings(String key, {required List<String> fallback}) {
    final String? override = _override(key);
    if (override != null) {
      final Iterable<String> items = override
          .split(',')
          .map((item) => item.trim());
      return List<String>.unmodifiable(items.where((i) => i.isNotEmpty));
    }
    final Object? value = _fileValue(key);
    if (value == null) {
      return List<String>.unmodifiable(fallback);
    }
    if (value is! List) {
      throw _invalid(key, 'a list', value);
    }
    final result = <String>[];
    for (var index = 0; index < value.length; index++) {
      final Object? element = value[index];
      final bool isScalar = element is String || element is num;
      if (!isScalar || '$element'.isEmpty) {
        throw InspectraConfigException(
          '${_child(key)}[$index]',
          'expected a non-empty string, got ${_describe(element)}.',
        );
      }
      result.add('$element');
    }
    return List<String>.unmodifiable(result);
  }

  /// Returns the non-empty list at [key] with each element mapped through
  /// [parse], which returns `null` for values it does not accept, or
  /// [fallback] when absent; [expected] describes the accepted values for
  /// the error message.
  ///
  /// Throws an [InspectraConfigException] for empty lists and unaccepted
  /// elements.
  List<T> enums<T>(
    String key, {
    required List<T> fallback,
    required T? Function(String value) parse,
    required String expected,
  }) {
    final bool present =
        _map[key] != null || overrides.lookup(_childKey(key)) != null;
    final List<String> raw = strings(key, fallback: const <String>[]);
    if (!present) {
      return List<T>.unmodifiable(fallback);
    }
    if (raw.isEmpty) {
      throw InspectraConfigException(
        _child(key),
        'expected at least one of $expected.',
      );
    }
    final result = <T>[];
    for (var index = 0; index < raw.length; index++) {
      final T? parsed = parse(raw[index]);
      if (parsed == null) {
        throw InspectraConfigException(
          '${_child(key)}[$index]',
          'expected one of $expected, got "${raw[index]}".',
        );
      }
      result.add(parsed);
    }
    return List<T>.unmodifiable(result);
  }

  /// Returns the value of [key] chosen from [options] by name, or
  /// [fallback] when absent.
  ///
  /// Throws an [InspectraConfigException] for names that are not options.
  T choice<T>(String key, Map<String, T> options, {required T fallback}) {
    final String? name = optionalString(key);
    if (name == null) {
      return fallback;
    }
    final T? selected = options[name.toLowerCase()];
    if (selected == null) {
      throw InspectraConfigException(
        _child(key),
        'expected one of ${options.keys.join(', ')}, got "$name".',
      );
    }
    return selected;
  }

  /// Rejects every key of this mapping that was never read.
  ///
  /// Throws an [InspectraConfigException] for the first unknown key.
  void ensureFullyRead() {
    for (final Object? key in _map.keys) {
      if (key is String && _read.contains(key)) {
        continue;
      }
      final List<String> known = _read.toList()..sort();
      throw InspectraConfigException(
        _child('$key'),
        'unknown option. Known options here: ${known.join(', ')}.',
      );
    }
  }

  /// Describes [value] for an error message.
  ///
  /// Returns a short description such as `"text"`, `a list` or `42`.
  static String _describe(Object? value) {
    if (value is YamlNode) {
      return _describe(value.value);
    }
    if (value is String) {
      return '"$value"';
    }
    if (value is Map) {
      return 'a mapping';
    }
    if (value is List) {
      return 'a list';
    }
    return '$value';
  }
}
