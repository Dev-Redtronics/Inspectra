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

/// The processor architecture Inspectra is running on.
enum CpuArchitecture {
  /// 64-bit x86, also known as amd64.
  x64('x64'),

  /// 64-bit ARM, also known as aarch64.
  arm64('arm64'),

  /// 32-bit ARM.
  arm('arm'),

  /// 32-bit x86, also known as 386.
  ia32('ia32'),

  /// 64-bit RISC-V.
  riscv64('riscv64'),

  /// Any other architecture.
  other('other');

  /// Creates an architecture with the identifier used by the Dart `Abi`
  /// naming scheme, for example `arm64` in `macos_arm64`.
  const CpuArchitecture(this.abiName);

  /// The identifier used by the Dart `Abi` naming scheme.
  final String abiName;

  /// Finds the architecture whose [abiName] equals [name].
  ///
  /// Returns the matching architecture, or [other] when none matches.
  static CpuArchitecture fromAbiName(String name) {
    final matches = values.where((cpu) => cpu.abiName == name);
    return matches.firstOrNull ?? CpuArchitecture.other;
  }
}
