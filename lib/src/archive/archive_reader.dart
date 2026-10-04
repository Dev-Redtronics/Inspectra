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

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:inspectra/src/archive/archive_entry.dart';
import 'package:inspectra/src/archive/archive_entry_kind.dart';
import 'package:inspectra/src/archive/archive_limits.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';

/// Reads `.tar.gz` and `.zip` archives into memory within strict limits.
///
/// Decompression is streamed through a bounded inflater, so a small archive
/// that expands to gigabytes is rejected after
/// [ArchiveLimits.maxExtractedBytes] instead of exhausting memory. Every
/// entry, including duplicates that a plain archive library would silently
/// merge, is returned.
final class ArchiveReader {
  /// Creates a reader enforcing [limits].
  const ArchiveReader(this.limits);

  /// The limits to enforce.
  final ArchiveLimits limits;

  /// The two magic bytes every gzip stream starts with.
  static const _gzipMagic = <int>[0x1F, 0x8B];

  /// The two magic bytes every zip file starts with, `PK`.
  static const _zipMagic = <int>[0x50, 0x4B];

  /// The tar type flags of regular files.
  static const _fileFlags = <String>{'0', '7', '', '\x00'};

  /// Reads a gzip compressed tar archive.
  ///
  /// Returns every entry in archive order.
  ///
  /// Throws an [InvalidInputException] when the archive is malformed or
  /// exceeds a limit.
  List<ArchiveEntry> readTarGz(Uint8List compressed) {
    _checkCompressedSize(compressed);
    final Uint8List tarBytes = _gunzip(compressed);
    final decoder = TarDecoder();
    try {
      decoder.decodeBytes(tarBytes);
      _checkEntryCount(decoder.files.length);
      return decoder.files.map(_tarEntry).toList();
    } on InspectraException {
      rethrow;
    } on ArchiveException catch (error) {
      throw InvalidInputException(
        'The archive is not a valid tar file: '
        '${error.message}',
      );
    } on Object {
      throw const InvalidInputException('The tar archive is malformed.');
    }
  }

  /// Reads a zip archive.
  ///
  /// Returns every entry in archive order.
  ///
  /// Throws an [InvalidInputException] when the archive is malformed or
  /// exceeds a limit.
  List<ArchiveEntry> readZip(Uint8List compressed) {
    _checkCompressedSize(compressed);
    final bool hasMagic =
        compressed.length > 4 &&
        compressed[0] == _zipMagic.first &&
        compressed[1] == _zipMagic.last;
    if (!hasMagic) {
      throw const InvalidInputException('The archive is not a zip file.');
    }
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(compressed);
    } on ArchiveException catch (error) {
      throw InvalidInputException(
        'The archive is not a valid zip file: '
        '${error.message}',
      );
    } on Object {
      throw const InvalidInputException('The zip archive is malformed.');
    }
    _checkEntryCount(archive.files.length);
    final int declared = archive.files.fold<int>(0, (sum, f) => sum + f.size);
    _checkExtractedSize(declared);
    return archive.files.map(_zipEntry).toList();
  }

  /// Converts a tar header into an entry.
  ///
  /// Returns the entry.
  ArchiveEntry _tarEntry(TarFile file) {
    final ArchiveEntryKind kind = _tarKind(file.typeFlag, file.filename);
    final Uint8List? content = kind == ArchiveEntryKind.file
        ? file.contentBytes
        : null;
    return ArchiveEntry(
      name: file.filename,
      kind: kind,
      mode: file.mode,
      linkTarget: file.nameOfLinkedFile,
      bytes: content ?? Uint8List(0),
    );
  }

  /// Maps a tar [typeFlag] to an entry kind.
  ///
  /// Returns the kind; directories may also be marked by a trailing slash.
  ArchiveEntryKind _tarKind(String typeFlag, String name) {
    if (typeFlag == TarFile.directory || name.endsWith('/')) {
      return ArchiveEntryKind.directory;
    }
    if (typeFlag == TarFile.symbolicLink) {
      return ArchiveEntryKind.symlink;
    }
    if (typeFlag == TarFile.hardLink) {
      return ArchiveEntryKind.hardLink;
    }
    if (_fileFlags.contains(typeFlag)) {
      return ArchiveEntryKind.file;
    }
    return ArchiveEntryKind.special;
  }

  /// Converts a zip member into an entry.
  ///
  /// Returns the entry.
  ArchiveEntry _zipEntry(ArchiveFile file) {
    if (file.isSymbolicLink) {
      return ArchiveEntry(
        name: file.name,
        kind: ArchiveEntryKind.symlink,
        mode: file.mode,
        linkTarget: file.symbolicLink,
        bytes: Uint8List(0),
      );
    }
    if (!file.isFile) {
      return ArchiveEntry(
        name: file.name,
        kind: ArchiveEntryKind.directory,
        mode: file.mode,
        bytes: Uint8List(0),
      );
    }
    final Uint8List content = file.readBytes() ?? Uint8List(0);
    _checkExtractedSize(content.length);
    return ArchiveEntry(
      name: file.name,
      kind: ArchiveEntryKind.file,
      mode: file.mode,
      bytes: content,
    );
  }

  /// Inflates [compressed] gzip data, aborting once the output exceeds the
  /// extraction limit.
  ///
  /// Returns the inflated bytes.
  ///
  /// Throws an [InvalidInputException] for corrupt data or oversized output.
  Uint8List _gunzip(Uint8List compressed) {
    final bool hasMagic =
        compressed.length > 2 &&
        compressed[0] == _gzipMagic.first &&
        compressed[1] == _gzipMagic.last;
    if (!hasMagic) {
      throw const InvalidInputException('The archive is not gzip data.');
    }
    final filter = RawZLibFilter.inflateFilter();
    final output = BytesBuilder(copy: false);
    try {
      filter.process(compressed, 0, compressed.length);
      for (
        List<int>? chunk = filter.processed(flush: false);
        chunk != null;
        chunk = filter.processed(flush: false)
      ) {
        output.add(chunk);
        _checkExtractedSize(output.length);
      }
      final List<int>? tail = filter.processed(end: true);
      if (tail != null) {
        output.add(tail);
        _checkExtractedSize(output.length);
      }
    } on FormatException catch (error) {
      throw InvalidInputException(
        'The archive is not valid gzip data: '
        '${error.message}',
      );
    }
    return output.takeBytes();
  }

  /// Rejects archives larger than the compressed size limit.
  void _checkCompressedSize(Uint8List compressed) {
    if (compressed.length > limits.maxArchiveBytes) {
      throw InvalidInputException(
        'The archive is ${compressed.length} bytes, more than the limit of '
        '${limits.maxArchiveBytes} bytes.',
      );
    }
  }

  /// Rejects archives that expand beyond the extraction limit.
  void _checkExtractedSize(int bytes) {
    if (bytes > limits.maxExtractedBytes) {
      throw InvalidInputException(
        'The archive expands to more than ${limits.maxExtractedBytes} bytes; '
        'it is rejected as a possible decompression bomb.',
      );
    }
  }

  /// Rejects archives with more entries than allowed.
  void _checkEntryCount(int count) {
    if (count > limits.maxEntries) {
      throw InvalidInputException(
        'The archive contains $count entries, more than the limit of '
        '${limits.maxEntries}.',
      );
    }
  }
}
