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

/// Where a dependency declared in `pubspec.yaml` is resolved from.
enum DependencyKind {
  /// A package registry such as pub.dev or a private server.
  hosted,

  /// A Git repository.
  git,

  /// A local directory.
  path,

  /// An SDK such as Flutter.
  sdk,
}
