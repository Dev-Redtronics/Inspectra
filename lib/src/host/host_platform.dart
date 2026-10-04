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

import 'dart:ffi';

import 'package:inspectra/src/host/cpu_architecture.dart';
import 'package:inspectra/src/host/operating_system.dart';

/// The operating system and processor architecture of the current machine.
///
/// The platform decides which Trivy release asset is downloaded, how
/// executables are looked up on the `PATH` and where caches are stored.
final class HostPlatform {
  /// Creates a platform description from an [operatingSystem] and an
  /// [architecture].
  const HostPlatform(this.operatingSystem, this.architecture);

  /// Detects the platform of the running Dart VM or native executable.
  ///
  /// The detection uses `Abi.current()`, which reports the architecture the
  /// binary was compiled for. That is exactly the architecture whose Trivy
  /// binary can be executed next to it.
  ///
  /// Returns the current platform.
  factory HostPlatform.current() => HostPlatform.fromAbi(Abi.current());

  /// Creates a platform description from a Dart [abi] such as
  /// `Abi.linuxX64`, whose string form is `linux_x64`.
  ///
  /// Returns the parsed platform; unknown parts map to `other`.
  factory HostPlatform.fromAbi(Abi abi) {
    final List<String> parts = abi.toString().split('_');
    final OperatingSystem system = OperatingSystem.fromAbiName(parts.first);
    final CpuArchitecture cpu = CpuArchitecture.fromAbiName(parts.last);
    return HostPlatform(system, cpu);
  }

  /// The operating system family.
  final OperatingSystem operatingSystem;

  /// The processor architecture.
  final CpuArchitecture architecture;

  /// Whether this is a Windows host.
  bool get isWindows => operatingSystem == OperatingSystem.windows;

  /// The separator of entries in the `PATH` variable.
  String get pathListSeparator => isWindows ? ';' : ':';

  /// Returns the platform as `system-architecture`, for example
  /// `linux-x64`.
  @override
  String toString() => '${operatingSystem.abiName}-${architecture.abiName}';
}
