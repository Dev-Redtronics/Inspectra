# Changelog

All notable changes to this project are documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to
[Semantic Versioning](https://semver.org/).

## 1.0.0

First release. Inspectra covers every command of `dart_audit` 0.3.1 with the same names, flags,
rule ids, JSON fields and the exit codes `0`, `1` and `64`, and adds:

### Added

- `scan`, the default command: OSV.dev audit, pubspec rules, typosquatting, dependency confusion
  and Trivy in one report, with `--recursive` for monorepos and pub workspaces.
- `trivy`: locates an installed Trivy or downloads a pinned, checksum verified release for Linux,
  macOS and Windows when (and only when) the download host is reachable. Mode, version (`latest`
  included), download, executable, mirror, scanners, severities and database mirror are all
  configurable.
- Configuration through `inspectra.yaml`, `INSPECTRA_*` variables and `--set key=value`, with
  validation of every key and value.
- Ignore rules with mandatory reason, optional package scope and expiry date.
- Output formats `json` (versioned), `sarif` (GitHub code scanning) and `markdown`; `--output`.
- Exit codes `65` (invalid input) and `69` (verification incomplete); `--exit-zero` never hides
  them. `--fail-on`, `--min-severity`, `--offline`, `--quiet`, `--verbose`, `--color`.
- Proxy, custom CA bundle, `PUB_HOSTED_URL`, OSV mirror, retries with back-off and `Retry-After`,
  response size limits and an OSV advisory cache.
- New rules: `TAG_CHARACTER`, `LINK_ENTRY`, `SPECIAL_FILE`, `SETUID_BIT`, `DUPLICATE_ENTRY`,
  `CASE_COLLISION`, `NATIVE_BINARY`, `BUILD_HOOK`, `INSECURE_URL`, `DOWNLOAD_AND_EXECUTE`,
  `ENCODED_POWERSHELL`, `RETRACTED_VERSION`, `DISCONTINUED`, `DEPENDENCY_CONFUSION`.
- `add --dry-run`; `trust <package> [version]`.

### Fixed compared to dart_audit

- OSV advisories are fetched in full (`querybatch` only returns ids), paginated, and their CVSS
  v3/v2 vectors are scored, so severities and fix versions are no longer "unknown".
- The fix version is taken from the range that contains the installed version.
- Package archives are verified against `archive_sha256` and read in memory: no zip-slip, no
  decompression bombs. The archive and pubspec scanners actually run.
- Trust signals use the endpoints pub.dev really provides (publisher, version history) and assess
  the requested version.
- The Unicode scanner works on code points, so supplementary plane carriers are detected; emoji
  presentation selectors and non-Latin prose are no longer reported.
- The URL rule matches hosts exactly (`github.com.evil.io` is no longer trusted) and ignores
  comments and links in messages; tests, examples and binaries are not scanned for code patterns.
- Typosquatting reports the closest popular package once and no longer flags `lints`, `http2`,
  `sqlite3`, `flutter_bloc` and similar official packages.
- `add` installs exactly the inspected version and works with Flutter on Windows.
- The Git hook reports its real location, covers nested packages and falls back to
  `dart run inspectra`.
- Running without a command runs the default command; `--version` reports Inspectra's version.
