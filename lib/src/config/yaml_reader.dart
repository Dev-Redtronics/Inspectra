import 'package:inspectra/src/config/config_exception.dart';
import 'package:yaml/yaml.dart';

/// A typed, strict view on one YAML mapping of the configuration.
///
/// Every key that is read is remembered, and [ensureFullyRead] rejects any key
/// that was not, so that a misspelled option fails loudly instead of being
/// ignored.
class YamlReader {
  /// Wraps [node], which lives at [path] in the configuration.
  YamlReader(Object? node, this.path) : _map = _asMap(node, path);

  /// The dotted path of this mapping.
  final String path;

  final Map<Object?, Object?> _map;
  final _read = <String>{};

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

  String _child(String key) => path.isEmpty ? key : '$path.$key';

  Object? _value(String key) {
    _read.add(key);
    return _map[key];
  }

  /// The nested mapping at [key], empty when absent.
  YamlReader section(String key) => YamlReader(_value(key), _child(key));

  /// The boolean at [key], or [fallback] when absent.
  bool boolean(String key, {required bool fallback}) {
    final Object? value = _value(key);
    if (value == null) {
      return fallback;
    }
    if (value is bool) {
      return value;
    }
    throw InspectraConfigException(
      _child(key),
      'expected true or false, got ${_describe(value)}.',
    );
  }

  /// The string at [key], or [fallback] when absent.
  String string(String key, {required String fallback}) =>
      optionalString(key) ?? fallback;

  /// The string at [key], or `null` when absent.
  String? optionalString(String key) {
    final Object? value = _value(key);
    if (value == null) {
      return null;
    }
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw InspectraConfigException(
      _child(key),
      'expected a non-empty string, got ${_describe(value)}.',
    );
  }

  /// The number at [key] between [min] and [max], or `null` when absent.
  double? optionalNumber(
    String key, {
    required double min,
    required double max,
  }) {
    final Object? value = _value(key);
    if (value == null) {
      return null;
    }
    if (value is num && value >= min && value <= max) {
      return value.toDouble();
    }
    throw InspectraConfigException(
      _child(key),
      'expected a number between $min and $max, got ${_describe(value)}.',
    );
  }

  /// The list of strings at [key], or [fallback] when absent.
  List<String> strings(String key, {required List<String> fallback}) {
    final Object? value = _value(key);
    if (value == null) {
      return List.unmodifiable(fallback);
    }
    if (value is! List) {
      throw InspectraConfigException(
        _child(key),
        'expected a list, got ${_describe(value)}.',
      );
    }
    final result = <String>[];
    for (var i = 0; i < value.length; i++) {
      final Object? element = value[i];
      if (element is! String || element.isEmpty) {
        throw InspectraConfigException(
          '${_child(key)}[$i]',
          'expected a non-empty string, got ${_describe(element)}.',
        );
      }
      result.add(element);
    }
    return List.unmodifiable(result);
  }

  /// The list at [key] with each element mapped through [parse], which returns
  /// `null` for values it does not accept; [expected] describes the accepted
  /// values for the error message.
  List<T> enums<T>(
    String key, {
    required List<T> fallback,
    required T? Function(String value) parse,
    required String expected,
  }) {
    final List<String> raw = strings(key, fallback: const []);
    if (_map[key] == null) {
      return List.unmodifiable(fallback);
    }
    final result = <T>[];
    for (var i = 0; i < raw.length; i++) {
      final T? parsed = parse(raw[i]);
      if (parsed == null) {
        throw InspectraConfigException(
          '${_child(key)}[$i]',
          'expected one of $expected, got "${raw[i]}".',
        );
      }
      result.add(parsed);
    }
    return List.unmodifiable(result);
  }

  /// Rejects every key of this mapping that was never read.
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
