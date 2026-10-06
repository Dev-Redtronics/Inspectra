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

/// The output formats of `inspectra graph`.
enum GraphFormat {
  /// One line per package with the packages it depends on.
  text('text'),

  /// Graphviz DOT, with a cluster per layer.
  dot('dot'),

  /// A Mermaid flowchart, with a subgraph per layer, for Markdown.
  mermaid('mermaid'),

  /// JSON with `nodes` and `edges`.
  json('json');

  /// Creates the format spelled [id] on the command line.
  const GraphFormat(this.id);

  /// The spelling on the command line.
  final String id;
}
