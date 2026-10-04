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

/// The POSIX shell pre-commit hook installed by `inspectra hook`.
///
/// The hook audits the *staged* content of every `pubspec.lock` and checks
/// every staged `pubspec.yaml` for typosquatting, in the repository root and
/// in every nested package of a monorepo. It prefers an `inspectra` binary on
/// the `PATH` and falls back to `dart run inspectra` for projects that use
/// Inspectra as a development dependency.
final class PreCommitScript {
  /// Prevents instantiation; this type only offers the script.
  const PreCommitScript._();

  /// The marker that identifies hooks installed by Inspectra. Only hooks
  /// carrying it are ever replaced or removed.
  static const marker = '# Installed by inspectra hook';

  /// The complete hook script.
  static const content =
      '''
#!/bin/sh
$marker
# Audits staged pubspec.lock and pubspec.yaml files before each commit.
# Bypass once with: git commit --no-verify
set -u

INSPECTRA="dart run inspectra"
command -v inspectra >/dev/null 2>&1 && INSPECTRA="inspectra"

STAGED=\$(git diff --cached --name-only --diff-filter=ACMR | grep -E '(^|/)pubspec\\.(yaml|lock)\$' || true)
[ -n "\$STAGED" ] || exit 0

TEMP_DIR=\$(mktemp -d) || exit 1
trap 'rm -rf "\$TEMP_DIR"' EXIT HUP INT TERM

STATUS=0
INDEX=0
while IFS= read -r FILE; do
  [ -n "\$FILE" ] || continue
  INDEX=\$((INDEX + 1))
  TARGET="\$TEMP_DIR/\$INDEX"
  mkdir -p "\$TARGET" || exit 1
  NAME=\$(basename "\$FILE")
  git show ":\$FILE" > "\$TARGET/\$NAME" || exit 1
  case "\$NAME" in
    pubspec.lock)
      echo "inspectra: auditing staged \$FILE"
      \$INSPECTRA audit --lockfile "\$TARGET/\$NAME" || STATUS=1
      ;;
    pubspec.yaml)
      echo "inspectra: checking staged \$FILE for typosquatting"
      \$INSPECTRA typosquat --pubspec "\$TARGET/\$NAME" || STATUS=1
      ;;
  esac
done <<INSPECTRA_FILES
\$STAGED
INSPECTRA_FILES

exit \$STATUS
''';
}
