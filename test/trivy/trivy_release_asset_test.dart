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

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/host/cpu_architecture.dart';
import 'package:inspectra/src/host/operating_system.dart';
import 'package:inspectra/src/trivy/trivy_release_asset.dart';
import 'package:test/test.dart';

/// Tests the mapping of hosts to Trivy release assets.
void main() {
  final expectations = <(OperatingSystem, CpuArchitecture), String?>{
    (OperatingSystem.linux, CpuArchitecture.x64):
        'trivy_0.75.0_Linux-64bit.tar.gz',
    (OperatingSystem.linux, CpuArchitecture.arm64):
        'trivy_0.75.0_Linux-ARM64.tar.gz',
    (OperatingSystem.linux, CpuArchitecture.arm):
        'trivy_0.75.0_Linux-ARM.tar.gz',
    (OperatingSystem.linux, CpuArchitecture.ia32):
        'trivy_0.75.0_Linux-32bit.tar.gz',
    (OperatingSystem.macos, CpuArchitecture.x64):
        'trivy_0.75.0_macOS-64bit.tar.gz',
    (OperatingSystem.macos, CpuArchitecture.arm64):
        'trivy_0.75.0_macOS-ARM64.tar.gz',
    (OperatingSystem.windows, CpuArchitecture.x64):
        'trivy_0.75.0_windows-64bit.zip',
    (OperatingSystem.windows, CpuArchitecture.arm64):
        'trivy_0.75.0_windows-64bit.zip',
    (OperatingSystem.linux, CpuArchitecture.riscv64): null,
    (OperatingSystem.other, CpuArchitecture.x64): null,
  };

  for (final MapEntry<(OperatingSystem, CpuArchitecture), String?> entry
      in expectations.entries) {
    final (OperatingSystem system, CpuArchitecture cpu) = entry.key;
    test('${system.abiName}-${cpu.abiName}', () {
      final TrivyReleaseAsset? asset = TrivyReleaseAsset.forHost(
        HostPlatform(system, cpu),
        'v0.75.0',
      );
      expect(asset?.archiveName, entry.value);
    });
  }

  test('builds release URLs below the configured base', () {
    final TrivyReleaseAsset asset = TrivyReleaseAsset.forHost(
      const HostPlatform(OperatingSystem.windows, CpuArchitecture.x64),
      '0.75.0',
    )!;
    expect(asset.binaryName, 'trivy.exe');
    expect(
      '${asset.checksumsUri('https://mirror/trivy')}',
      'https://mirror/trivy/v0.75.0/trivy_0.75.0_checksums.txt',
    );
  });
}
