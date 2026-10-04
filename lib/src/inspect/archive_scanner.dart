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

import 'dart:typed_data';

import 'package:inspectra/src/archive/archive_entry.dart';
import 'package:inspectra/src/archive/archive_entry_kind.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/model/source_location.dart';
import 'package:inspectra/src/report/snippet_sanitizer.dart';

/// Checks the structure of a package archive for attacks and surprises.
///
/// Rules:
///
/// * `PATH_TRAVERSAL` and `ABSOLUTE_PATH` (CRITICAL): entries that would be
///   written outside the extraction directory, including Windows drive
///   paths;
/// * `LINK_ENTRY` (HIGH, CRITICAL when escaping): symbolic and hard links;
/// * `SPECIAL_FILE` (HIGH): devices and FIFOs;
/// * `SETUID_BIT` (HIGH): files with the setuid or setgid bit;
/// * `DUPLICATE_ENTRY` (HIGH): the same path twice, where the later entry
///   silently replaces the reviewed one;
/// * `CASE_COLLISION` (MEDIUM): paths that collide on case-insensitive file
///   systems;
/// * `HIDDEN_EXECUTABLE` (HIGH): hidden scripts;
/// * `NATIVE_BINARY` (MEDIUM): executables and native libraries, detected by
///   extension and by ELF, PE and Mach-O magic numbers;
/// * `BUILD_HOOK` (MEDIUM): `hook/build.dart` and `hook/link.dart`, which
///   run automatically during `dart build` and `flutter build`;
/// * `OVERLONG_NAME` (HIGH): names longer than 4096 characters.
final class ArchiveScanner {
  /// Creates a scanner.
  const ArchiveScanner();

  /// The longest acceptable entry name.
  static const maxNameLength = 4096;

  /// Extensions of hidden files that are executable.
  static const _scriptExtensions = <String>{
    '.dart',
    '.sh',
    '.bat',
    '.cmd',
    '.ps1',
  };

  /// Extensions of native binaries.
  static const _binaryExtensions = <String>{
    '.so',
    '.dll',
    '.dylib',
    '.exe',
    '.jar',
    '.bin',
    '.node',
  };

  /// Magic numbers of executable formats: ELF, PE, Mach-O 32/64 bit and
  /// universal binaries.
  static const _magicNumbers = <List<int>>[
    <int>[0x7F, 0x45, 0x4C, 0x46],
    <int>[0x4D, 0x5A],
    <int>[0xFE, 0xED, 0xFA, 0xCE],
    <int>[0xFE, 0xED, 0xFA, 0xCF],
    <int>[0xCE, 0xFA, 0xED, 0xFE],
    <int>[0xCF, 0xFA, 0xED, 0xFE],
    <int>[0xCA, 0xFE, 0xBA, 0xBE],
  ];

  /// The setuid and setgid permission bits.
  static const _setIdBits = 0xC00;

  /// Scans [entries].
  ///
  /// Returns the findings ordered by severity.
  List<Finding> scan(List<ArchiveEntry> entries) {
    final findings = <Finding>[
      for (final entry in entries) ..._scanEntry(entry),
      ..._duplicates(entries),
    ];
    return findings..sort((a, b) => a.severity.rank.compareTo(b.severity.rank));
  }

  /// Applies the per entry rules to [entry].
  ///
  /// Returns the findings of that entry.
  List<Finding> _scanEntry(ArchiveEntry entry) {
    final findings = <Finding>[];
    final List<String> segments = entry.path.split('/');
    if (entry.name.length > maxNameLength) {
      findings.add(
        _finding(
          entry,
          'OVERLONG_NAME',
          Severity.high,
          'Archive entry name exceeds $maxNameLength characters',
        ),
      );
    }
    if (segments.contains('..')) {
      findings.add(
        _finding(
          entry,
          'PATH_TRAVERSAL',
          Severity.critical,
          'Path traversal — the entry escapes the extraction root',
        ),
      );
    }
    if (_isAbsolute(entry.name)) {
      findings.add(
        _finding(
          entry,
          'ABSOLUTE_PATH',
          Severity.critical,
          'Absolute path in archive — would write outside the package',
        ),
      );
    }
    final Finding? link = _linkFinding(entry);
    if (link != null) {
      findings.add(link);
    }
    if (entry.kind == ArchiveEntryKind.special) {
      findings.add(
        _finding(
          entry,
          'SPECIAL_FILE',
          Severity.high,
          'Device node or FIFO in a package archive',
        ),
      );
    }
    if (entry.isFile && (entry.mode & _setIdBits) != 0) {
      findings.add(
        _finding(
          entry,
          'SETUID_BIT',
          Severity.high,
          'File carries the setuid or setgid permission bit',
        ),
      );
    }
    findings.addAll(_contentFindings(entry));
    return findings;
  }

  /// Applies the rules that look at file names and contents.
  ///
  /// Returns the findings of that entry.
  List<Finding> _contentFindings(ArchiveEntry entry) {
    if (!entry.isFile) {
      return const <Finding>[];
    }
    final findings = <Finding>[];
    final String name = entry.baseName;
    final String extension = _extension(name);
    if (name.startsWith('.') && _scriptExtensions.contains(extension)) {
      findings.add(
        _finding(
          entry,
          'HIDDEN_EXECUTABLE',
          Severity.high,
          'Hidden file with executable extension: $name',
        ),
      );
    }
    if (_binaryExtensions.contains(extension) || _hasMagic(entry.bytes)) {
      findings.add(
        _finding(
          entry,
          'NATIVE_BINARY',
          Severity.medium,
          'Prebuilt native binary — its behaviour cannot be reviewed',
        ),
      );
    }
    if (entry.path == 'hook/build.dart' || entry.path == 'hook/link.dart') {
      findings.add(
        _finding(
          entry,
          'BUILD_HOOK',
          Severity.medium,
          'Build hook that runs automatically when the app is built',
        ),
      );
    }
    return findings;
  }

  /// Checks link entries.
  ///
  /// Returns a finding for links, CRITICAL when the target escapes the
  /// package, otherwise `null`.
  Finding? _linkFinding(ArchiveEntry entry) {
    final bool isLink =
        entry.kind == ArchiveEntryKind.symlink ||
        entry.kind == ArchiveEntryKind.hardLink;
    if (!isLink) {
      return null;
    }
    final String target = (entry.linkTarget ?? '').replaceAll(r'\', '/');
    final bool escapes =
        _isAbsolute(target) || target.split('/').contains('..');
    return _finding(
      entry,
      'LINK_ENTRY',
      escapes ? Severity.critical : Severity.high,
      'Link entry pointing to "${SnippetSanitizer.sanitize(target)}"',
    );
  }

  /// Reports paths that occur more than once, exactly or ignoring case.
  ///
  /// Returns the findings.
  List<Finding> _duplicates(List<ArchiveEntry> entries) {
    final findings = <Finding>[];
    final exact = <String>{};
    final folded = <String, String>{};
    for (final ArchiveEntry entry in entries.where(
      (e) => e.kind != ArchiveEntryKind.directory,
    )) {
      final String path = entry.path;
      final String lower = path.toLowerCase();
      if (!exact.add(path)) {
        findings.add(
          _finding(
            entry,
            'DUPLICATE_ENTRY',
            Severity.high,
            'The path occurs more than once; the later entry wins',
          ),
        );
        continue;
      }
      final String? previous = folded[lower];
      if (previous != null) {
        findings.add(
          _finding(
            entry,
            'CASE_COLLISION',
            Severity.medium,
            'Collides with "$previous" on case-insensitive file systems',
          ),
        );
        continue;
      }
      folded[lower] = path;
    }
    return findings;
  }

  /// Whether [name] is an absolute POSIX, UNC or Windows drive path.
  ///
  /// Returns `true` for absolute paths.
  bool _isAbsolute(String name) =>
      name.startsWith('/') ||
      name.startsWith(r'\') ||
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(name);

  /// Whether [bytes] start with the magic number of an executable format.
  ///
  /// Returns `true` for native executables and libraries.
  bool _hasMagic(Uint8List bytes) {
    for (final List<int> magic in _magicNumbers) {
      if (bytes.length < magic.length) {
        continue;
      }
      var matches = true;
      for (var index = 0; index < magic.length; index++) {
        matches = matches && bytes[index] == magic[index];
      }
      if (matches) {
        return true;
      }
    }
    return false;
  }

  /// Returns the lower case extension of [fileName], including the dot.
  String _extension(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    return dot <= 0 ? '' : fileName.substring(dot).toLowerCase();
  }

  /// Creates a finding for [entry].
  ///
  /// Returns the finding.
  Finding _finding(
    ArchiveEntry entry,
    String rule,
    Severity severity,
    String description,
  ) => Finding(
    ruleId: rule,
    source: FindingSource.archive,
    severity: severity,
    title: description,
    location: SourceLocation(SnippetSanitizer.sanitize(entry.path)),
    attributes: <String, Object?>{'entryName': entry.path},
  );
}
