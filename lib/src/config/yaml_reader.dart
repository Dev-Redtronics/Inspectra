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
import 'package:inspectra/src/config/config_kind.dart';
import 'package:inspectra/src/config/config_origin.dart';
import 'package:inspectra/src/config/config_override.dart';
import 'package:inspectra/src/config/config_overrides.dart';
import 'package:inspectra/src/config/config_recorder.dart';
import 'package:inspectra/src/config/config_suggestion.dart';
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
/// the option expects; lists are comma separated. With a [recorder], every
/// value is recorded with its default and its origin.
final class YamlReader {
  /// Wraps [node], which lives at the dotted [path] in the configuration,
  /// with the shared [overrides] and [recorder].
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
    this.recorder,
  }) : _map = _asMap(node, path),
       _yaml = node is YamlMap ? node : null,
       keyPath = keyPath ?? path,
       overrides = overrides ?? ConfigOverrides.none();

  /// The dotted path of this mapping, empty for the root.
  final String path;

  /// The logical dotted path of this mapping, used to look up overrides.
  final String keyPath;

  /// The overrides shared by every reader of one configuration.
  final ConfigOverrides overrides;

  /// Records every value read, or `null` when nothing is recorded.
  final ConfigRecorder? recorder;

  /// The wrapped mapping.
  final Map<Object?, Object?> _map;

  /// The wrapped mapping as parsed YAML, which knows the line of each key,
  /// or `null` for a mapping that was built in code.
  final YamlMap? _yaml;

  /// The keys that have been read.
  final _read = <String>{};

  /// The words an override may use for `true`.
  static const _truthy = <String>{'true', 'yes', '1', 'on'};

  /// The words an override may use for `false`.
  static const _falsy = <String>{'false', 'no', '0', 'off'};

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
  /// Returns the override, or `null` when the key is not overridden.
  ConfigOverride? _override(String key) {
    _read.add(key);
    return overrides.resolve(_childKey(key));
  }

  /// Marks [key] as read and returns its value in the file.
  ///
  /// Returns the value, or `null` when absent.
  Object? _fileValue(String key) {
    _read.add(key);
    final Object? value = _map[key];
    return value is YamlNode ? value.value : value;
  }

  /// Returns the line of [key] in the configuration file, or `null` when it
  /// is not known.
  int? _line(String key) {
    final YamlMap? yaml = _yaml;
    if (yaml == null) {
      return null;
    }
    for (final Object? node in yaml.nodes.keys) {
      if (node is YamlNode && node.value == key) {
        return node.span.start.line + 1;
      }
    }
    return null;
  }

  /// Records [value] of [key] of the [kind] with its [fallback]; the value
  /// comes from [override], from the file when [fromFile] is set, and is
  /// the default otherwise.
  void _note(
    String key,
    ConfigKind kind, {
    required Object? value,
    required Object? fallback,
    ConfigOverride? override,
    bool fromFile = false,
    List<String>? options,
    num? minimum,
    num? maximum,
  }) {
    final ConfigOrigin origin =
        override?.origin ??
        (fromFile ? ConfigOrigin.file : ConfigOrigin.defaults);
    recorder?.record(
      ConfigEntry(
        key: _childKey(key),
        kind: kind,
        value: ConfigEntry.jsonOf(value),
        defaultValue: ConfigEntry.jsonOf(fallback),
        origin: origin,
        variable: override?.variable,
        line: origin == ConfigOrigin.file ? _line(key) : null,
        options: options,
        minimum: minimum,
        maximum: maximum,
      ),
    );
  }

  /// Replaces the recorded entry of [key]: [kind], [options], [fallback]
  /// as its default and, when its value is unset, [fallback] as its value
  /// from the default.
  void _complete(
    String key, {
    required Object? fallback,
    ConfigKind? kind,
    List<String>? options,
    Object? value,
    bool replaceValue = false,
    String? fallbackVariable,
    num? minimum,
  }) {
    final ConfigRecorder? target = recorder;
    final ConfigEntry? entry = target?[_childKey(key)];
    if (target == null || entry == null) {
      return;
    }
    final bool unset = entry.value == null && !replaceValue;
    final ConfigOrigin origin = unset && fallbackVariable != null
        ? ConfigOrigin.environment
        : entry.origin;
    target.record(
      ConfigEntry(
        key: entry.key,
        kind: kind ?? entry.kind,
        value: unset
            ? ConfigEntry.jsonOf(fallback)
            : replaceValue
            ? ConfigEntry.jsonOf(value)
            : entry.value,
        defaultValue: ConfigEntry.jsonOf(fallback),
        origin: origin,
        variable: unset ? fallbackVariable : entry.variable,
        line: entry.line,
        options: options ?? entry.options,
        minimum: minimum ?? entry.minimum,
        maximum: entry.maximum,
      ),
    );
  }

  /// Records [value] of [key] that a section computed itself, for example
  /// from a legacy environment variable, with its [origin], the
  /// environment [variable] and its default [fallback].
  void recordValue(
    String key,
    ConfigKind kind,
    Object? value, {
    required ConfigOrigin origin,
    String? variable,
    Object? fallback,
  }) {
    final ConfigEntry? previous = recorder?[_childKey(key)];
    recorder?.record(
      ConfigEntry(
        key: _childKey(key),
        kind: kind,
        value: ConfigEntry.jsonOf(value),
        defaultValue: ConfigEntry.jsonOf(fallback ?? previous?.defaultValue),
        origin: origin,
        variable: variable,
        line: origin == ConfigOrigin.file ? _line(key) : null,
      ),
    );
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
      recorder: recorder,
    );
  }

  /// The keys of this mapping as written in the file, in file order, for
  /// sections whose keys are names chosen by the user.
  List<String> get fileKeys => List<String>.unmodifiable(<String>[
    for (final Object? key in _map.keys) '$key',
  ]);

  /// Returns the raw value at [key] for structured options, such as the
  /// `ignore` list, that only the file can express; [fallback] is what an
  /// absent value means, for the record.
  Object? structured(String key, {Object? fallback}) {
    final Object? value = _fileValue(key);
    _note(
      key,
      ConfigKind.structured,
      value: value ?? fallback,
      fallback: fallback,
      fromFile: value != null,
    );
    return value;
  }

  /// Returns the boolean at [key], or [fallback] when absent.
  ///
  /// Throws an [InspectraConfigException] for anything but a boolean.
  bool boolean(String key, {required bool fallback}) {
    final bool? value = optionalBoolean(key);
    _complete(key, fallback: fallback);
    return value ?? fallback;
  }

  /// Returns the boolean at [key], or `null` when absent.
  ///
  /// Throws an [InspectraConfigException] for anything but a boolean.
  bool? optionalBoolean(String key) {
    final ConfigOverride? override = _override(key);
    if (override != null) {
      final String text = override.value.trim().toLowerCase();
      final bool? parsed = _truthy.contains(text)
          ? true
          : _falsy.contains(text)
          ? false
          : null;
      if (parsed == null) {
        throw _invalid(key, 'true or false', text);
      }
      _note(
        key,
        ConfigKind.boolean,
        value: parsed,
        fallback: null,
        override: override,
      );
      return parsed;
    }
    final Object? value = _fileValue(key);
    if (value != null && value is! bool) {
      throw _invalid(key, 'true or false', value);
    }
    _note(
      key,
      ConfigKind.boolean,
      value: value,
      fallback: null,
      fromFile: value != null,
    );
    return value as bool?;
  }

  /// Returns the string at [key], or [fallback] when absent; with
  /// [fallbackVariable], the fallback was taken from that environment
  /// variable. With [allowEmpty], an empty string is a value of its own,
  /// such as a changelog tag prefix of `''`.
  ///
  /// Throws an [InspectraConfigException] for anything but a non-empty
  /// string, or any string with [allowEmpty].
  String string(
    String key, {
    required String fallback,
    String? fallbackVariable,
    bool allowEmpty = false,
  }) {
    final String? value = allowEmpty
        ? _possiblyEmptyString(key)
        : optionalString(key);
    _complete(key, fallback: fallback, fallbackVariable: fallbackVariable);
    return value ?? fallback;
  }

  /// Returns the string at [key], which may be empty, or `null` when absent.
  ///
  /// Throws an [InspectraConfigException] for anything but a scalar.
  String? _possiblyEmptyString(String key) {
    final ConfigOverride? override = _override(key);
    if (override != null) {
      final String text = override.value.trim();
      _note(
        key,
        ConfigKind.string,
        value: text,
        fallback: null,
        override: override,
      );
      return text;
    }
    final Object? value = _fileValue(key);
    if (value != null && value is! String && value is! num) {
      throw _invalid(key, 'a string', value);
    }
    final String? text = value == null ? null : '$value';
    _note(
      key,
      ConfigKind.string,
      value: text,
      fallback: null,
      fromFile: text != null,
    );
    return text;
  }

  /// Returns the string at [key], or `null` when absent. Numbers in the
  /// file are accepted as their text, so `version: 0.75` reads as `0.75`.
  ///
  /// Throws an [InspectraConfigException] for anything but a non-empty
  /// scalar.
  String? optionalString(String key) {
    final ConfigOverride? override = _override(key);
    final String? text = override?.value.trim();
    if (text != null && text.isNotEmpty) {
      _note(
        key,
        ConfigKind.string,
        value: text,
        fallback: null,
        override: override,
      );
      return text;
    }
    final Object? value = _fileValue(key);
    if (value == null) {
      _note(key, ConfigKind.string, value: null, fallback: null);
      return null;
    }
    final bool isScalar = value is String || value is num;
    if (isScalar && '$value'.isNotEmpty) {
      _note(
        key,
        ConfigKind.string,
        value: '$value',
        fallback: null,
        fromFile: true,
      );
      return '$value';
    }
    throw _invalid(key, 'a non-empty string', value);
  }

  /// Returns the number at [key] between [min] and [max], or [fallback]
  /// when absent.
  ///
  /// Throws an [InspectraConfigException] for anything else.
  double number(
    String key, {
    required double min,
    required double max,
    required double fallback,
  }) {
    final double? value = optionalNumber(key, min: min, max: max);
    _complete(key, fallback: fallback);
    return value ?? fallback;
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
    final ConfigOverride? override = _override(key);
    final Object? value = override == null
        ? _fileValue(key)
        : double.tryParse(override.value.trim()) ?? override.value;
    final bool valid = value is num && value >= min && value <= max;
    if (value != null && !valid) {
      throw _invalid(key, 'a number between $min and $max', value);
    }
    final double? number = value is num ? value.toDouble() : null;
    _note(
      key,
      ConfigKind.number,
      value: number,
      fallback: null,
      override: override,
      fromFile: number != null,
      minimum: min,
      maximum: max,
    );
    return number;
  }

  /// Returns the whole number at [key] between [min] and [max], or
  /// [fallback] when absent.
  ///
  /// Throws an [InspectraConfigException] for anything else.
  int integer(
    String key, {
    required int min,
    required int max,
    required int fallback,
  }) {
    final int? value = optionalInt(key, min: min, max: max);
    _complete(key, fallback: fallback);
    return value ?? fallback;
  }

  /// Returns the whole number at [key] between [min] and [max], or `null`
  /// when absent.
  ///
  /// Throws an [InspectraConfigException] for anything else.
  int? optionalInt(String key, {required int min, required int max}) {
    final ConfigOverride? override = _override(key);
    final Object? value = override == null
        ? _fileValue(key)
        : int.tryParse(override.value.trim()) ?? override.value;
    final bool valid = value is int && value >= min && value <= max;
    if (value != null && !valid) {
      throw _invalid(key, 'a whole number between $min and $max', value);
    }
    final int? number = value is int ? value : null;
    _note(
      key,
      ConfigKind.integer,
      value: number,
      fallback: null,
      override: override,
      fromFile: number != null,
      minimum: min,
      maximum: max,
    );
    return number;
  }

  /// Returns the duration at [key], written as `500ms`, `30s`, `10m` or `1h`
  /// (a bare number means seconds), or [fallback] when absent.
  ///
  /// Throws an [InspectraConfigException] for malformed durations.
  Duration duration(String key, {required Duration fallback}) {
    final ConfigOverride? override = _override(key);
    final Object? value = override?.value ?? _fileValue(key);
    if (value == null) {
      _note(key, ConfigKind.duration, value: fallback, fallback: fallback);
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
    final parsed = Duration(
      milliseconds: amount * (milliseconds[match[2] ?? 's'] ?? 1),
    );
    _note(
      key,
      ConfigKind.duration,
      value: parsed,
      fallback: fallback,
      override: override,
      fromFile: true,
    );
    return parsed;
  }

  /// Returns the list of strings at [key], or [fallback] when absent. An
  /// override is a comma separated list.
  ///
  /// Throws an [InspectraConfigException] for anything but a list of
  /// non-empty strings.
  List<String> strings(String key, {required List<String> fallback}) {
    final ConfigOverride? override = _override(key);
    if (override != null) {
      final items = List<String>.unmodifiable(
        override.value
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty),
      );
      _note(
        key,
        ConfigKind.strings,
        value: items,
        fallback: fallback,
        override: override,
      );
      return items;
    }
    final Object? value = _fileValue(key);
    if (value == null) {
      _note(key, ConfigKind.strings, value: fallback, fallback: fallback);
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
    _note(
      key,
      ConfigKind.strings,
      value: result,
      fallback: fallback,
      fromFile: true,
    );
    return List<String>.unmodifiable(result);
  }

  /// Returns the non-empty list at [key] with each element mapped through
  /// [parse], which returns `null` for values it does not accept, or
  /// [fallback] when absent; [options] are the accepted names, which
  /// [name] gives each value. Only with [allowEmpty] may the list be empty.
  ///
  /// Throws an [InspectraConfigException] for an empty list or values that
  /// [parse] rejects.
  List<T> enums<T>(
    String key, {
    required List<T> fallback,
    required T? Function(String value) parse,
    required List<String> options,
    required String Function(T value) name,
    bool allowEmpty = false,
  }) {
    final minItems = allowEmpty ? 0 : 1;
    final bool present =
        _map[key] != null || overrides.resolve(_childKey(key)) != null;
    final List<String> raw = strings(key, fallback: const <String>[]);
    final List<String> defaults = fallback.map(name).toList();
    if (!present) {
      _complete(
        key,
        fallback: defaults,
        kind: ConfigKind.enumList,
        options: options,
        value: defaults,
        replaceValue: true,
        minimum: minItems,
      );
      return List<T>.unmodifiable(fallback);
    }
    final String expected = options.join(', ');
    if (raw.isEmpty && !allowEmpty) {
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
    _complete(
      key,
      fallback: defaults,
      kind: ConfigKind.enumList,
      options: options,
      value: result.map(name).toList(),
      replaceValue: true,
      minimum: minItems,
    );
    return List<T>.unmodifiable(result);
  }

  /// Returns the value of [key] chosen from [options] by name, or
  /// [fallback] when absent.
  ///
  /// Throws an [InspectraConfigException] for names that are not options.
  T choice<T>(String key, Map<String, T> options, {required T fallback}) {
    final String? name = optionalString(key);
    final String? fallbackName = options.entries
        .where((entry) => entry.value == fallback)
        .map((entry) => entry.key)
        .firstOrNull;
    final T? selected = name == null ? null : options[name.toLowerCase()];
    if (name != null && selected == null) {
      throw InspectraConfigException(
        _child(key),
        'expected one of ${options.keys.join(', ')}, got "$name".',
      );
    }
    _complete(
      key,
      fallback: fallbackName,
      kind: ConfigKind.choice,
      options: options.keys.toList(),
      value: name?.toLowerCase() ?? fallbackName,
      replaceValue: true,
    );
    return name == null ? fallback : selected as T;
  }

  /// Rejects every key of this mapping that was never read.
  ///
  /// Throws an [InspectraConfigException] for the first unknown key, with
  /// the closest known key as a suggestion.
  void ensureFullyRead() {
    for (final Object? key in _map.keys) {
      if (key is String && _read.contains(key)) {
        continue;
      }
      final List<String> known = _read.toList()..sort();
      throw InspectraConfigException(
        _child('$key'),
        'unknown option.${didYouMean('$key', known)} Known options here: '
        '${known.join(', ')}.',
      );
    }
  }

  /// Describes [value] for an error message.
  ///
  /// Returns the description.
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
