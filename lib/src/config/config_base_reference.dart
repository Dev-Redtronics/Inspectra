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
import 'package:yaml/yaml.dart';

/// One entry of `extends`: a configuration the declaring file builds on.
sealed class ConfigBaseReference {
  /// Creates a reference.
  const ConfigBaseReference();

  /// The base as written in `extends`, used to name it in messages.
  String get label;

  /// Reads the `extends` value [node] found at [path] of a file, which is
  /// the base [file] or `null` for the project's own configuration.
  ///
  /// Returns the references in their order, empty when [node] is `null`.
  ///
  /// Throws an [InspectraConfigException] for anything but a path, a
  /// `package:` URI or a pinned URL, or a list of them.
  static List<ConfigBaseReference> listOf(
    Object? node,
    String path, {
    String? file,
  }) {
    final Object? value = node is YamlNode ? node.value : node;
    if (value == null) {
      return const <ConfigBaseReference>[];
    }
    if (value is List) {
      return <ConfigBaseReference>[
        for (var index = 0; index < value.length; index++)
          _parse(value[index], '$path[$index]', file),
      ];
    }
    return <ConfigBaseReference>[_parse(value, path, file)];
  }

  /// Reads one entry [node] at [path] of [file].
  ///
  /// Returns the reference.
  ///
  /// Throws an [InspectraConfigException] when it is malformed.
  static ConfigBaseReference _parse(Object? node, String path, String? file) {
    final Object? value = node is YamlNode ? node.value : node;
    if (value is Map<Object?, Object?>) {
      return RemoteBaseReference._fromMap(value, path, file);
    }
    final String text = value is String ? value.trim() : '';
    if (text.isEmpty) {
      throw InspectraConfigException(
        path,
        'expected a path, a package: URI or an entry with url and sha256.',
        file: file,
      );
    }
    final bool isUrl =
        text.startsWith('https://') || text.startsWith('http://');
    if (isUrl) {
      throw InspectraConfigException(
        path,
        'a URL needs a SHA-256 pin: write "- url: $text" and "sha256: <hex>".',
        file: file,
      );
    }
    if (!text.startsWith('package:')) {
      return PathBaseReference(text);
    }
    final String rest = text.substring('package:'.length);
    final int slash = rest.indexOf('/');
    if (slash <= 0 || slash == rest.length - 1) {
      throw InspectraConfigException(
        path,
        'expected package:<name>/<path>, got "$text".',
        file: file,
      );
    }
    return PackageBaseReference(
      rest.substring(0, slash),
      rest.substring(slash + 1),
    );
  }
}

/// A base file named by a path relative to the file that extends it.
final class PathBaseReference extends ConfigBaseReference {
  /// Creates the reference to [path].
  const PathBaseReference(this.path);

  /// The path as written, relative to the declaring file's directory.
  final String path;

  /// Returns the path as written.
  @override
  String get label => path;
}

/// A base file of a package, resolved through
/// `.dart_tool/package_config.json`.
final class PackageBaseReference extends ConfigBaseReference {
  /// Creates the reference to [path] within the libraries of [package].
  const PackageBaseReference(this.package, this.path);

  /// The name of the package.
  final String package;

  /// The path below the package's `lib/` directory.
  final String path;

  /// Returns the `package:` URI.
  @override
  String get label => 'package:$package/$path';
}

/// A base downloaded from [url] whose content must have the SHA-256
/// [sha256].
final class RemoteBaseReference extends ConfigBaseReference {
  /// Creates the reference to [url] pinned to [sha256].
  const RemoteBaseReference(this.url, this.sha256);

  /// Reads the entry [map] at [path] of [file].
  ///
  /// Returns the reference.
  ///
  /// Throws an [InspectraConfigException] for unknown keys, a URL that is
  /// not `https` (plain `http` is accepted for the local machine only) or a
  /// malformed pin.
  factory RemoteBaseReference._fromMap(
    Map<Object?, Object?> map,
    String path,
    String? file,
  ) {
    for (final Object? key in map.keys) {
      if (key != 'url' && key != 'sha256') {
        throw InspectraConfigException(
          '$path.$key',
          'unknown option. Known options here: sha256, url.',
          file: file,
        );
      }
    }
    final Object? url = map['url'];
    final Uri? uri = url is String ? Uri.tryParse(url.trim()) : null;
    final bool secure =
        uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'https' ||
            uri.scheme == 'http' && _loopback.contains(uri.host));
    if (uri == null || !secure) {
      throw InspectraConfigException(
        '$path.url',
        'expected an https URL, got ${url is String ? '"$url"' : 'nothing'}.',
        file: file,
      );
    }
    final Object? pin = map['sha256'];
    final String hex = pin is String ? pin.trim().toLowerCase() : '';
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hex)) {
      throw InspectraConfigException(
        '$path.sha256',
        'expected the SHA-256 of the file as 64 hexadecimal digits.',
        file: file,
      );
    }
    return RemoteBaseReference(uri, hex);
  }

  /// The hosts that may be reached without TLS: the local machine.
  static const _loopback = <String>{'localhost', '127.0.0.1', '::1', '[::1]'};

  /// Where the base is downloaded from.
  final Uri url;

  /// The lower case hexadecimal SHA-256 the content must have.
  final String sha256;

  /// Returns the URL.
  @override
  String get label => '$url';
}
