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

/// The formats a report can be rendered in.
enum OutputFormat {
  /// Coloured, human readable text.
  text('text'),

  /// A versioned JSON document for machines.
  json('json'),

  /// SARIF 2.1.0 for code scanning platforms such as GitHub.
  sarif('sarif'),

  /// GitHub flavoured Markdown, for pull request comments and job summaries.
  markdown('markdown'),

  /// JUnit XML, for the test reports of Jenkins, Azure DevOps and GitLab.
  junit('junit'),

  /// The Code Quality JSON of GitLab merge requests.
  gitlab('gitlab'),

  /// The generic issue import of SonarQube and SonarCloud.
  sonarqube('sonarqube'),

  /// Checkstyle XML, for Jenkins Warnings NG, Bitbucket and IDEs.
  checkstyle('checkstyle'),

  /// A self-contained HTML dashboard for people.
  html('html');

  /// Creates a format with its command line spelling [id].
  const OutputFormat(this.id);

  /// The spelling accepted by `--format`.
  final String id;

  /// Finds the format spelled [id].
  ///
  /// Returns the format, or [text] when [id] is unknown, which cannot happen
  /// for values validated by the argument parser.
  static OutputFormat fromId(String id) =>
      values.where((format) => format.id == id).firstOrNull ?? text;
}
