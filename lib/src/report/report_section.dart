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

import 'package:inspectra/src/metrics/line_counts.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/section_details.dart';
import 'package:inspectra/src/report/section_status.dart';

/// One evaluation of a report, such as the lint check or the supply-chain
/// scan: its outcome, a summary, key figures and findings.
final class ReportSection {
  /// Creates the section [id] titled [title] with its [status] and
  /// [summary]; [reason] explains a skipped or failed run.
  const ReportSection({
    required this.id,
    required this.title,
    required this.status,
    required this.summary,
    this.metrics = const <String, String>{},
    this.findings = const <Finding>[],
    this.details = const NoDetails(),
    this.reason,
  });

  /// Reads a section from its JSON [json], found at [location].
  ///
  /// Returns the section.
  ///
  /// Throws an [InvalidInputException] when the JSON is no section.
  factory ReportSection.fromJson(Object? json, String location) {
    if (json is! Map<String, Object?>) {
      throw InvalidInputException('$location must be an object.');
    }
    final Object? id = json['id'];
    final Object? title = json['title'];
    final Object? summary = json['summary'];
    final SectionStatus? status = SectionStatus.tryParse('${json['status']}');
    final bool valid =
        id is String && title is String && summary is String && status != null;
    if (!valid) {
      throw InvalidInputException(
        '$location needs an id, a title, a summary and a status.',
      );
    }
    final Object? metrics = json['metrics'];
    final Object? findings = json['findings'];
    final Object? reason = json['reason'];
    return ReportSection(
      id: id,
      title: title,
      status: status,
      summary: summary,
      metrics: <String, String>{
        if (metrics is Map<String, Object?>)
          for (final MapEntry<String, Object?> metric in metrics.entries)
            metric.key: '${metric.value}',
      },
      findings: <Finding>[
        if (findings is List<Object?>)
          for (var index = 0; index < findings.length; index++)
            Finding.fromJson(findings[index], '$location.findings[$index]'),
      ],
      details: _detailsOf(json['details']),
      reason: reason is String ? reason : null,
    );
  }

  /// The stable identifier, such as `lint` or `trivy-secret`.
  final String id;

  /// The title shown in reports.
  final String title;

  /// The outcome.
  final SectionStatus status;

  /// A one-line summary of the outcome.
  final String summary;

  /// Key figures, such as `Files: 120`, in display order.
  final Map<String, String> metrics;

  /// The findings of the evaluation.
  final List<Finding> findings;

  /// Further details, such as the coverage of every file.
  final SectionDetails details;

  /// Why the section was skipped or could not run, if it was.
  final String? reason;

  /// Returns the findings at or above [threshold].
  List<Finding> findingsAtLeast(Severity threshold) => findings
      .where((finding) => finding.severity.isAtLeast(threshold))
      .toList();

  /// Serializes the section for the JSON report.
  ///
  /// Returns the JSON object.
  Map<String, Object?> toJson() {
    final Map<String, Object?> detailsJson = details.toJson();
    return <String, Object?>{
      'id': id,
      'title': title,
      'status': status.id,
      'summary': summary,
      'reason': ?reason,
      'metrics': metrics,
      'findings': <Map<String, Object?>>[
        for (final finding in findings) finding.toJson(),
      ],
      if (detailsJson.isNotEmpty) 'details': detailsJson,
    };
  }

  /// Reads the [json] details of a section.
  ///
  /// Returns coverage or diff details, or [NoDetails].
  static SectionDetails _detailsOf(Object? json) {
    if (json is! Map<String, Object?>) {
      return const NoDetails();
    }
    final Object? diff = json['diff'];
    if (diff is String) {
      return DiffDetails(diff);
    }
    final Object? areas = json['areas'];
    if (areas is List<Object?>) {
      return _codebaseOf(json, areas);
    }
    final Object? percent = json['percent'];
    final Object? files = json['files'];
    if (percent is! num || files is! List<Object?>) {
      return const NoDetails();
    }
    final Object? minimum = json['minimum'];
    final Object? untested = json['untested'];
    return CoverageDetails(
      percent: percent.toDouble(),
      minimum: minimum is num ? minimum.toDouble() : null,
      files: <(String, int, int)>[
        for (final Object? file in files)
          if (file case {
            'path': final String path,
            'linesFound': final int found,
            'linesHit': final int hit,
          })
            (path, found, hit),
      ],
      untested: <String>[
        if (untested is List<Object?>)
          for (final Object? path in untested)
            if (path is String) path,
      ],
    );
  }

  /// Reads the codebase details [json] with its [areas].
  ///
  /// Returns the details; malformed entries are left out.
  static CodebaseDetails _codebaseOf(
    Map<String, Object?> json,
    List<Object?> areas,
  ) {
    final Object? largest = json['largest'];
    final Object? generated = json['generated'];
    final (Object? files, Object? lines) = generated is Map<String, Object?>
        ? (generated['files'], generated['lines'])
        : (null, null);
    return CodebaseDetails(
      areas: <(String, int, LineCounts)>[
        for (final Object? area in areas)
          if (area case {'name': final String name, 'files': final int count})
            (name, count, LineCounts.fromJson(area)),
      ],
      largest: <(String, LineCounts)>[
        if (largest is List<Object?>)
          for (final Object? file in largest)
            if (file case {'path': final String path})
              (path, LineCounts.fromJson(file)),
      ],
      generatedFiles: files is int ? files : 0,
      generatedLines: lines is int ? lines : 0,
    );
  }
}
