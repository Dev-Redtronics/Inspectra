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

/// The type of a configuration option, as the configuration file spells it.
enum ConfigKind {
  /// `true` or `false`.
  boolean,

  /// A text; numbers are accepted and read as text.
  string,

  /// A whole number within a range.
  integer,

  /// A number within a range.
  number,

  /// A duration such as `30s`, `10m` or `1h`; a bare number means seconds.
  duration,

  /// A list of texts.
  strings,

  /// A list of names from a fixed set.
  enumList,

  /// One name from a fixed set.
  choice,

  /// Raw YAML with a structure of its own, such as the `ignore` list.
  structured,
}
