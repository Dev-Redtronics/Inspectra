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

import '../model/finding.dart';
import 'command_report.dart';
import 'severity_breakdown.dart';

/// Renders reports as GitHub flavoured Markdown.
///
/// The output is meant for pull request comments and the
/// `$GITHUB_STEP_SUMMARY` of a workflow run: a severity summary followed by a
/// table of every finding.
final class MarkdownReportWriter {
  /// Creates a writer.
  const MarkdownReportWriter();

  /// Renders [report].
  ///
  /// Returns the Markdown document.
  String render(CommandReport report) {
    final out = StringBuffer()
      ..writeln('## Inspectra `${report.command}` report')
      ..writeln();
    final findings = report.findings;
    if (findings.isEmpty) {
      out.writeln('No findings. :white_check_mark:');
      return out.toString();
    }
    out
      ..writeln(
        '**${findings.length} finding(s):** ${severityBreakdown(findings)}',
      )
      ..writeln()
      ..writeln('| Severity | Rule | Where | Summary |')
      ..writeln('| --- | --- | --- | --- |');
    for (final finding in findings) {
      out.writeln(
        '| ${finding.severity.label} | ${_cell(_rule(finding))} '
        '| ${_cell(_where(finding))} | ${_cell(finding.title)} |',
      );
    }
    return out.toString();
  }

  /// Formats the rule id, linked when a URL is known.
  ///
  /// Returns the Markdown fragment.
  String _rule(Finding finding) {
    final url = finding.url;
    if (url == null) {
      return '`${finding.ruleId}`';
    }
    return '[`${finding.ruleId}`]($url)';
  }

  /// Formats the package or file the finding refers to.
  ///
  /// Returns the Markdown fragment.
  String _where(Finding finding) {
    final package = finding.packageName;
    if (package != null) {
      return '$package ${finding.packageVersion ?? ''}'.trim();
    }
    return finding.location?.toString() ?? '';
  }

  /// Escapes [text] for use inside a table cell.
  ///
  /// Returns the escaped single line text.
  String _cell(String text) =>
      text.replaceAll('|', r'\|').replaceAll(RegExp(r'[\r\n]+'), ' ');
}
