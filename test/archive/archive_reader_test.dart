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

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/archive/archive_entry.dart';
import 'package:inspectra/src/archive/archive_entry_kind.dart';
import 'package:inspectra/src/archive/archive_limits.dart';
import 'package:inspectra/src/archive/archive_reader.dart';
import 'package:test/test.dart';

import '../support/archive_fixtures.dart';

/// Tests in-memory archive reading and its limits.
void main() {
  const limits = ArchiveLimits(
    maxArchiveBytes: 1 << 20,
    maxExtractedBytes: 1 << 20,
    maxEntries: 100,
  );

  test('reads every tar.gz entry with its content', () {
    final List<ArchiveEntry> entries = const ArchiveReader(
      limits,
    ).readTarGz(buildTarGz(<String, String>{'lib/a.dart': 'void main() {}'}));
    expect(entries.single.path, 'lib/a.dart');
    expect(entries.single.text, 'void main() {}');
    expect(entries.single.kind, ArchiveEntryKind.file);
    expect(entries.single.isText, isTrue);
  });

  test('keeps duplicate entries that archive libraries would merge', () {
    final archive = Archive()
      ..addFile(ArchiveFile.string('lib/a.dart', 'one'))
      ..addFile(ArchiveFile.string('lib/b.dart', 'two'));
    final Uint8List tar = TarEncoder().encodeBytes(archive);
    final duplicated = <int>[...tar.sublist(0, tar.length - 1024)];
    final Uint8List second = TarEncoder().encodeBytes(
      Archive()..addFile(ArchiveFile.string('lib/a.dart', 'evil')),
    );
    duplicated.addAll(second);
    final gz = Uint8List.fromList(const GZipEncoder().encodeBytes(duplicated));
    final List<ArchiveEntry> entries = const ArchiveReader(limits)
        .readTarGz(gz);
    expect(entries.where((e) => e.path == 'lib/a.dart'), hasLength(2));
  });

  test('rejects decompression bombs', () {
    final Uint8List bomb = buildTarGz(<String, String>{
      'big.txt': '0' * (2 << 20),
    });
    expect(
      () => const ArchiveReader(limits).readTarGz(bomb),
      throwsA(isA<InvalidInputException>()),
    );
  });

  test('rejects archives with too many entries', () {
    final Uint8List many = buildTarGz(<String, String>{
      for (var i = 0; i < 150; i++) 'f$i.txt': '$i',
    });
    expect(
      () => const ArchiveReader(limits).readTarGz(many),
      throwsA(isA<InvalidInputException>()),
    );
  });

  test('rejects garbage as invalid input', () {
    expect(
      () => const ArchiveReader(limits).readTarGz(Uint8List.fromList(<int>[1])),
      throwsA(isA<InvalidInputException>()),
    );
    expect(
      () => const ArchiveReader(limits).readZip(Uint8List.fromList(<int>[1])),
      throwsA(isA<InvalidInputException>()),
    );
  });

  test('reads zip archives', () {
    final List<ArchiveEntry> entries = const ArchiveReader(limits).readZip(
      buildZip(<String, List<int>>{
        'trivy.exe': <int>[0x4D, 0x5A, 0],
      }),
    );
    expect(entries.single.path, 'trivy.exe');
    expect(entries.single.isText, isFalse);
  });
}
