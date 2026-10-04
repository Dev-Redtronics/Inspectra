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

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/host/cache_directory.dart';
import 'package:inspectra/src/host/cpu_architecture.dart';
import 'package:inspectra/src/host/operating_system.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Tests the per-platform cache directory conventions.
void main() {
  /// Resolves the cache directory on [system] with [variables].
  String? resolve(OperatingSystem system, Map<String, String> variables) =>
      CacheDirectory(
        environment: Environment(variables),
        host: HostPlatform(system, CpuArchitecture.x64),
      ).resolve();

  test('INSPECTRA_CACHE_DIR always wins', () {
    expect(
      resolve(OperatingSystem.linux, <String, String>{
        'INSPECTRA_CACHE_DIR': '/ci/cache',
        'HOME': '/home/u',
      }),
      '/ci/cache',
    );
  });

  test('follows each operating system convention', () {
    expect(
      resolve(OperatingSystem.linux, <String, String>{'HOME': '/home/u'}),
      p.join('/home/u', '.cache', 'inspectra'),
    );
    expect(
      resolve(OperatingSystem.linux, <String, String>{
        'HOME': '/home/u',
        'XDG_CACHE_HOME': '/xdg',
      }),
      p.join('/xdg', 'inspectra'),
    );
    expect(
      resolve(OperatingSystem.macos, <String, String>{'HOME': '/Users/u'}),
      p.join('/Users/u', 'Library/Caches', 'inspectra'),
    );
    expect(
      resolve(OperatingSystem.windows, <String, String>{
        'LOCALAPPDATA': r'C:\Users\u\AppData\Local',
      }),
      p.join(r'C:\Users\u\AppData\Local', 'inspectra'),
    );
    expect(resolve(OperatingSystem.other, const <String, String>{}), isNull);
  });

  test('detects the running platform', () {
    final host = HostPlatform.current();
    expect(host.operatingSystem, isNot(OperatingSystem.other));
    expect('$host', contains('-'));
  });
}
