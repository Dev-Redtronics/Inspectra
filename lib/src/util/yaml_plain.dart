import 'package:yaml/yaml.dart';

/// Converts parsed YAML nodes into plain Dart maps, lists and scalars, with
/// every map key turned into a string.
///
/// Parsers of `pubspec.yaml` and `pubspec.lock` use it to work with ordinary
/// `Map<String, Object?>` values and pattern matching instead of YAML node
/// types.
///
/// Returns the converted value.
Object? toPlainValue(Object? value) {
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
