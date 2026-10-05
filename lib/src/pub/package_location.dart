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

import 'package:path/path.dart' as p;

/// Where a package of `.dart_tool/package_config.json` lives on disk.
final class PackageLocation {
  /// Creates the location of a package in the directory [root] whose
  /// `package:` URIs resolve below [packageUri], usually `lib/`.
  const PackageLocation({required this.root, this.packageUri = 'lib/'});

  /// The absolute directory of the package.
  final String root;

  /// The directory of its libraries relative to [root], usually `lib/`.
  final String packageUri;

  /// Returns the absolute file of the `package:` URI path [path], such as
  /// `inspectra.yaml` for `package:acme_policy/inspectra.yaml`.
  String resolve(String path) => p.normalize(p.join(root, packageUri, path));
}
