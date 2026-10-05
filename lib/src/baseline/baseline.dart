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

import 'dart:convert';
import 'dart:io';

import 'package:inspectra/src/baseline/baseline_candidate.dart';
import 'package:inspectra/src/baseline/baseline_entry.dart';
import 'package:inspectra/src/baseline/baseline_scope.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/report/snippet_sanitizer.dart';

/// The findings a package has accepted for now, read from and written to
/// its committed baseline file.
///
/// A finding whose key is recorded is not reported until more findings of
/// that key occur than were recorded. The file is written sorted and
/// without timestamps, so that every change shows up as a minimal diff.
final class Baseline {
  /// Creates a baseline of [entries], sorted by key.
  Baseline(List<BaselineEntry> entries)
    : entries = List<BaselineEntry>.unmodifiable(
        <BaselineEntry>[...entries]..sort((a, b) => a.key.compareTo(b.key)),
      );

  /// Reads the baseline file at [path].
  ///
  /// Returns the baseline, or an empty one when the file does not exist.
  ///
  /// Throws an [InvalidInputException] when the file is malformed and an
  /// [UnavailableException] when it cannot be read.
  factory Baseline.load(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return Baseline(const <BaselineEntry>[]);
    }
    try {
      return Baseline.parse(file.readAsStringSync(), path);
    } on FileSystemException catch (error) {
      throw UnavailableException(
        'Cannot read the baseline $path: ${error.message}',
      );
    }
  }

  /// Parses the baseline [text] read from [source].
  ///
  /// Returns the baseline.
  ///
  /// Throws an [InvalidInputException] naming [source] when the text is no
  /// baseline of a supported schema version.
  factory Baseline.parse(String text, String source) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException catch (error) {
      throw InvalidInputException(
        'The baseline $source is no valid JSON: ${error.message}',
      );
    }
    if (json is! Map<String, Object?>) {
      throw InvalidInputException(
        'The baseline $source must be a JSON object.',
      );
    }
    final Object? version = json['schemaVersion'];
    if (version != schemaVersion) {
      throw InvalidInputException(
        'The baseline $source has the schemaVersion $version; this version '
        'of Inspectra reads $schemaVersion.',
      );
    }
    final Object? entries = json['entries'];
    if (entries is! List<Object?>) {
      throw InvalidInputException(
        'The baseline $source needs an "entries" list.',
      );
    }
    return Baseline(<BaselineEntry>[
      for (var index = 0; index < entries.length; index++)
        BaselineEntry.fromJson(entries[index], '$source: entries[$index]'),
    ]);
  }

  /// The version of the file layout this class reads and writes.
  static const schemaVersion = 1;

  /// The recorded entries, sorted by key.
  final List<BaselineEntry> entries;

  /// Whether nothing is recorded.
  bool get isEmpty => entries.isEmpty;

  /// Returns how many findings of [scope] are recorded.
  int countOf(BaselineScope scope) => entries
      .where((entry) => entry.scope == scope)
      .fold(0, (sum, entry) => sum + entry.count);

  /// Replaces the entries that [covers] selects with [candidates].
  ///
  /// Entries outside of [covers] - other scopes, or Trivy scans that did
  /// not run - are kept unchanged.
  ///
  /// Returns the new baseline.
  Baseline record(
    bool Function(BaselineEntry entry) covers,
    List<BaselineCandidate> candidates,
  ) {
    final groups = <String, List<BaselineCandidate>>{};
    for (final candidate in candidates) {
      groups
          .putIfAbsent(candidate.key, () => <BaselineCandidate>[])
          .add(candidate);
    }
    final List<BaselineEntry> recorded = groups.values.map(_entryOf).toList();
    return Baseline(<BaselineEntry>[
      ...entries.where((entry) => !covers(entry)),
      ...recorded,
    ]);
  }

  /// Removes what was fixed from the entries that [covers] selects: each
  /// count drops to the number of [candidates] of its key, and an entry
  /// without any is removed. Nothing is ever added.
  ///
  /// Returns the new baseline.
  Baseline prune(
    bool Function(BaselineEntry entry) covers,
    List<BaselineCandidate> candidates,
  ) {
    final current = <String, int>{};
    for (final candidate in candidates) {
      current.update(candidate.key, (count) => count + 1, ifAbsent: () => 1);
    }
    final kept = <BaselineEntry>[];
    for (final BaselineEntry entry in entries) {
      if (!covers(entry)) {
        kept.add(entry);
        continue;
      }
      final int remaining = current[entry.key] ?? 0;
      if (remaining == 0) {
        continue;
      }
      kept.add(remaining < entry.count ? entry.withCount(remaining) : entry);
    }
    return Baseline(kept);
  }

  /// Serializes the baseline.
  ///
  /// Returns the JSON object of the file.
  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'entries': <Map<String, Object?>>[
      for (final entry in entries) entry.toJson(),
    ],
  };

  /// Returns the text of the baseline file: indented JSON with a final
  /// line break.
  String render() {
    final String json = const JsonEncoder.withIndent('  ').convert(toJson());
    return '$json\n';
  }

  /// Writes the baseline to [path], atomically through a temporary file next
  /// to it.
  ///
  /// Throws an [UnavailableException] when the file cannot be written.
  void write(String path) {
    final temporary = File('$path.tmp');
    try {
      temporary.parent.createSync(recursive: true);
      temporary
        ..writeAsStringSync(render(), flush: true)
        ..renameSync(path);
    } on FileSystemException catch (error) {
      throw UnavailableException(
        'Cannot write the baseline $path: ${error.message}',
      );
    }
  }

  /// Builds the entry of a group of [candidates] that share one key.
  ///
  /// Returns an entry with their count, their highest severity and the title
  /// of the first of them.
  static BaselineEntry _entryOf(List<BaselineCandidate> candidates) {
    final ordered = <BaselineCandidate>[...candidates]
      ..sort((a, b) => (a.line ?? 0).compareTo(b.line ?? 0));
    final BaselineCandidate first = ordered.first;
    final BaselineCandidate worst = ordered.reduce(
      (a, b) => b.severity.rank < a.severity.rank ? b : a,
    );
    return BaselineEntry(
      scope: first.scope,
      source: first.source,
      rule: first.rule,
      count: ordered.length,
      severity: worst.severity,
      title: SnippetSanitizer.sanitize(first.title),
      package: first.package,
      path: first.path,
    );
  }
}
