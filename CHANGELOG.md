# Changelog

All notable changes to this project are documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to
[Semantic Versioning](https://semver.org/).

## 1.0.0

### Package quality gates

- Trivy scans for secrets, dependency licenses, dependency vulnerabilities and a plain filesystem
  scan, configurable per scan and runnable from `build_runner` or the `inspectra` command line.
- Public API dump of every public library, written by the `inspectra:api` builder and checked with
  `build_runner build --only-check` or `inspectra api check`; constants and `const` primary
  constructors are recorded and changes are shown as a unified diff.
- Coverage gate on top of `package:coverage` with an optional line coverage threshold; files marked
  `// coverage:ignore-file` are not listed as untested.
- Format check (`dart format`) and lint check (`dart analyze`, `fail_on: error|warning|info|none`)
  with `--fix`, as the first steps of `check`, and as `build_runner` builders.
- A strict lint preset, `package:inspectra/lints/strict.yaml`.
- Writerside documentation in `docs/`, published to GitHub Pages.

### Changelog

- `inspectra changelog generate` writes the section of the next release from the Conventional Commits
  since the latest release tag, in the Keep a Changelog layout: breaking changes first, then Added,
  Changed, Deprecated, Removed, Fixed and Security, with commit and comparison links. It suggests the
  next semantic version, drops commits reverted within the release, and with `--write` adds the section
  to `CHANGELOG.md` without touching existing sections. `--from`, `--to`, `--release`, `--date`.
- `inspectra changelog check`, also part of `check` with `changelog.enabled`, validates the changelog
  and fails when the version of `pubspec.yaml` is not documented.
- `inspectra changelog notes [version]` prints the section of a release; the release workflow uses it
  as the description of the GitHub release.
- The `changelog:` configuration section: `enabled`, `file`, `tag_prefix`, `types`, `unconventional`,
  `repository`, `commit_url`, `compare_url`; `checkChangelog` in the library API.

### Supply-chain security

Every command of `dart_audit` 0.3.1 with the same names, flags, rule ids, JSON fields and the exit
codes `0`, `1` and `64`:

- `scan`, the default command: OSV.dev audit, pubspec rules, typosquatting, dependency confusion
  and a Trivy filesystem scan in one report, with `--recursive` for monorepos and pub workspaces.
- `audit`, `inspect`, `trust [version]`, `typosquat`, `add [--dev] [--force] [--dry-run]`, `hook`.
- Output formats `json` (versioned), `sarif` (GitHub code scanning) and `markdown`; `--output`,
  `--fail-on`, `--min-severity`, `--ignore`, `--exit-zero`, `--offline`, `--quiet`, `--verbose`,
  `--color`.
- Ignore rules with mandatory reason, optional package scope and expiry date.
- Proxy, custom CA bundle, `PUB_HOSTED_URL`, OSV mirror, retries with back-off and `Retry-After`,
  response size limits and an OSV advisory cache.

Fixed compared to `dart_audit`: full OSV records with pagination, CVSS v3/v2 scoring and per-range
fix versions; checksum verified, in-memory package inspection without zip-slip or decompression
bombs; the archive and pubspec scanners actually run; correct pub.dev trust endpoints for the
requested version; code point based Unicode scanning; exact URL host matching; far fewer typosquat
false positives; `add` installs exactly the inspected version and works with Flutter on Windows.

### Trivy provisioning

- Trivy is taken from `trivy.executable` / `INSPECTRA_TRIVY`, the `PATH`, package manager
  directories or Inspectra's cache, or downloaded for Linux, macOS and Windows when the download host
  is reachable, with mandatory SHA-256 verification against the release checksums and atomic
  installation. `mode`, `version` (`latest` included), `download`, `use_installed`, mirrors and the
  database repository are configurable. `inspectra trivy --install` and `--where`; `--where`
  never downloads.
- `--offline` and `network.offline` keep Trivy offline as well: every scan, including the builders,
  starts it with `--skip-db-update --offline-scan`.

### Configuration and command line

- One configuration, in the `inspectra:` section of `pubspec.yaml` or in `inspectra.yaml`, with
  strict validation of every key; configuration errors name the key and, for YAML syntax errors, the
  line and column.
- Every option can be overridden with `INSPECTRA_*` environment variables and `--set key=value`.
- Exit codes follow `sysexits.h`: `65` for invalid input or configuration, `69` for unavailable
  services and tools, `70` for internal errors.
