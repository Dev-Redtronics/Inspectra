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

/// The POSIX shell pre-commit hook installed by `inspectra hook`.
///
/// The hook runs `inspectra hook run`, which checks the *staged* files with
/// the checks of `hook.checks`: by default it audits every staged
/// `pubspec.lock` and checks every staged `pubspec.yaml` for typosquatting.
/// It prefers an `inspectra` binary on the `PATH` and falls back to
/// `dart run inspectra` for projects that use Inspectra as a development
/// dependency.
final class PreCommitScript {
  /// Prevents instantiation; this type only offers the script.
  const PreCommitScript._();

  /// The marker that identifies hooks installed by Inspectra. Only hooks
  /// carrying it are ever replaced or removed.
  static const marker = '# Installed by inspectra hook';

  /// The complete hook script: it hands over to `inspectra hook run`,
  /// which runs the checks of `hook.checks` on the staged files.
  static const content =
      '''
#!/bin/sh
$marker
# Runs the checks of hook.checks in the Inspectra configuration on the
# staged files before each commit. Bypass once with: git commit --no-verify
set -u

INSPECTRA="dart run inspectra"
command -v inspectra >/dev/null 2>&1 && INSPECTRA="inspectra"

exec \$INSPECTRA hook run
''';
}
