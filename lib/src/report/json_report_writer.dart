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

import 'dart:convert';

import '../version.dart';
import 'command_report.dart';

/// Renders reports as versioned JSON documents.
///
/// The document always starts with `schemaVersion`, `tool`, `generatedAt`
/// and `command`, followed by the command specific body, which keeps every
/// field name of the equivalent `dart_audit` output. When the body has no
/// `findings` key, the normalised findings are added under that key.
final class JsonReportWriter {
  /// Creates a writer.
  const JsonReportWriter();

  /// The version of the document layout; incremented on breaking changes.
  static const int schemaVersion = 1;

  /// Renders [report] generated at [generatedAt].
  ///
  /// Returns the pretty printed JSON document followed by a line break.
  String render(CommandReport report, DateTime generatedAt) {
    final body = report.toJson();
    final document = <String, Object?>{
      'schemaVersion': schemaVersion,
      'tool': <String, Object?>{
        'name': 'inspectra',
        'version': inspectraVersion,
      },
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      'command': report.command,
      ...body,
      if (!body.containsKey('findings'))
        'findings': report.findings.map((f) => f.toJson()).toList(),
    };
    return '${const JsonEncoder.withIndent('  ').convert(document)}\n';
  }
}
