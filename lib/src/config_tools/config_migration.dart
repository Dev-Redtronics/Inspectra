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

import 'package:inspectra/src/config/deprecated_option.dart';

/// The result of renaming the old option names of a configuration file.
final class ConfigMigration {
  /// Creates the migration that turned a file into [content] by the
  /// [renamed] options.
  const ConfigMigration({required this.content, required this.renamed});

  /// The text of the file with every old name replaced.
  final String content;

  /// The old names that were replaced, in file order.
  final List<DeprecatedOption> renamed;

  /// Whether any name was replaced.
  bool get changed => renamed.isNotEmpty;
}
