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

import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/report/json_report_writer.dart';
import 'package:inspectra/src/report/markdown_report_writer.dart';
import 'package:inspectra/src/report/output_format.dart';
import 'package:inspectra/src/report/sarif_report_writer.dart';

/// Renders a [CommandReport] in the requested [OutputFormat].
final class ReportRenderer {
  /// Creates a renderer.
  const ReportRenderer();

  /// Renders [report] as [format], using [style] for text output and
  /// stamping machine readable formats with [generatedAt].
  ///
  /// Returns the rendered document.
  String render(
    CommandReport report,
    OutputFormat format, {
    required AnsiStyler style,
    required DateTime generatedAt,
  }) => switch (format) {
    OutputFormat.text => _text(report, style),
    OutputFormat.json => const JsonReportWriter().render(report, generatedAt),
    OutputFormat.sarif => const SarifReportWriter().render(report),
    OutputFormat.markdown => const MarkdownReportWriter().render(report),
  };

  /// Renders the human readable layout of [report].
  ///
  /// Returns the text.
  String _text(CommandReport report, AnsiStyler style) {
    final out = StringBuffer();
    report.writeText(out, style);
    return out.toString();
  }
}
