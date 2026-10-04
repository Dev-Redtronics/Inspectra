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

import 'package:inspectra/src/host/cpu_architecture.dart';
import 'package:inspectra/src/host/host_platform.dart';
import 'package:inspectra/src/host/operating_system.dart';

/// The Trivy release archive that runs on a given host.
///
/// Trivy publishes its releases with GoReleaser using the naming scheme
/// `trivy_<version>_<OS>-<arch>.tar.gz` (`.zip` on Windows), accompanied by
/// `trivy_<version>_checksums.txt`, below
/// `<downloadBaseUrl>/v<version>/`.
final class TrivyReleaseAsset {
  /// Creates the asset of [version] for the platform label [platformLabel],
  /// for example `Linux-64bit`.
  const TrivyReleaseAsset({
    required this.version,
    required this.platformLabel,
    required this.isZip,
  });

  /// The platform labels used by Trivy's release assets.
  ///
  /// Windows on ARM runs the x64 build through the built-in emulation.
  static const _labels = <OperatingSystem, Map<CpuArchitecture, String>>{
    OperatingSystem.linux: <CpuArchitecture, String>{
      CpuArchitecture.x64: 'Linux-64bit',
      CpuArchitecture.arm64: 'Linux-ARM64',
      CpuArchitecture.arm: 'Linux-ARM',
      CpuArchitecture.ia32: 'Linux-32bit',
    },
    OperatingSystem.macos: <CpuArchitecture, String>{
      CpuArchitecture.x64: 'macOS-64bit',
      CpuArchitecture.arm64: 'macOS-ARM64',
    },
    OperatingSystem.windows: <CpuArchitecture, String>{
      CpuArchitecture.x64: 'windows-64bit',
      CpuArchitecture.arm64: 'windows-64bit',
    },
  };

  /// Finds the asset of [version] for [host].
  ///
  /// A leading `v` in [version] is ignored.
  ///
  /// Returns the asset, or `null` when Trivy publishes no build for [host].
  static TrivyReleaseAsset? forHost(HostPlatform host, String version) {
    final String? label = _labels[host.operatingSystem]?[host.architecture];
    if (label == null) {
      return null;
    }
    return TrivyReleaseAsset(
      version: normaliseVersion(version),
      platformLabel: label,
      isZip: host.isWindows,
    );
  }

  /// Removes a leading `v` from [version].
  ///
  /// Returns the bare version, for example `0.75.0`.
  static String normaliseVersion(String version) =>
      version.startsWith('v') ? version.substring(1) : version;

  /// The bare Trivy version, for example `0.75.0`.
  final String version;

  /// The platform part of the archive name.
  final String platformLabel;

  /// Whether the archive is a zip file (Windows) instead of a `.tar.gz`.
  final bool isZip;

  /// The archive file name.
  String get archiveName =>
      'trivy_${version}_$platformLabel.${isZip ? 'zip' : 'tar.gz'}';

  /// The checksum file name.
  String get checksumsName => 'trivy_${version}_checksums.txt';

  /// The name of the executable inside the archive.
  String get binaryName => isZip ? 'trivy.exe' : 'trivy';

  /// Returns the archive URL below [baseUrl].
  Uri archiveUri(String baseUrl) =>
      Uri.parse('$baseUrl/v$version/$archiveName');

  /// Returns the checksum file URL below [baseUrl].
  Uri checksumsUri(String baseUrl) =>
      Uri.parse('$baseUrl/v$version/$checksumsName');
}
