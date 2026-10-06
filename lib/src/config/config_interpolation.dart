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

import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/io/environment.dart';

/// A reference to an environment variable in a configuration value:
/// `${env:NAME}` or, with a default for an unset variable,
/// `${env:NAME:-default}`. `$${` writes a literal `${`.
final _reference = RegExp(r'\$(\$?)\{([^}]*)\}');

/// The form of the text between the braces of a reference.
final _variable = RegExp(r'^env:([A-Za-z_][A-Za-z0-9_]*)(?::-(.*))?$');

/// Whether [text] contains a reference to an environment variable or an
/// escaped `$${`, so that [interpolate] would change it.
bool isInterpolated(String text) => text.contains(r'${');

/// Replaces every `${env:NAME}` in [text], the value at the dotted [path]
/// of the configuration file [file], with the variable from [environment],
/// and `$${` with a literal `${`.
///
/// Returns the text with the references resolved.
///
/// Throws an [InspectraConfigException] for a reference that is not of the
/// form `${env:NAME}` or `${env:NAME:-default}`, and for an unset variable
/// without a default.
String interpolate(
  String text,
  Environment environment, {
  required String path,
  String? file,
}) => text.replaceAllMapped(_reference, (match) {
  final String inner = match[2] ?? '';
  final bool escaped = (match[1] ?? '').isNotEmpty;
  if (escaped) {
    return '\${$inner}';
  }
  final RegExpMatch? reference = _variable.firstMatch(inner);
  if (reference == null) {
    throw InspectraConfigException(
      path,
      '"\${$inner}" is no reference; write '
      r'${env:NAME} or ${env:NAME:-default}, or $${ for a literal ${.',
      file: file,
    );
  }
  final String name = reference[1] ?? '';
  final String? fallback = reference[2];
  final String? value = environment[name] ?? fallback;
  if (value == null) {
    throw InspectraConfigException(
      path,
      'the environment variable $name is not set; set it or give a default '
      'with \${env:$name:-default}.',
      file: file,
    );
  }
  return value;
});
