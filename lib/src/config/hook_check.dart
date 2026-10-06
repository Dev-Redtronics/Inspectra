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

/// A check the pre-commit hook runs on the staged files, an entry of
/// `hook.checks`.
enum HookCheck {
  /// The OSV.dev audit of a staged `pubspec.lock`.
  audit('audit'),

  /// The typosquatting and dependency confusion check of a staged
  /// `pubspec.yaml`.
  typosquat('typosquat'),

  /// The pubspec rules and the dependency policy of a staged
  /// `pubspec.yaml`.
  deps('deps'),

  /// The format check of the staged Dart files.
  format('format'),

  /// The style check of the staged Dart files.
  style('style');

  /// Creates the check spelled [id] in the configuration.
  const HookCheck(this.id);

  /// The spelling in the configuration.
  final String id;
}
