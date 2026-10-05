# Changelog

All notable changes to this project are documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to
[Semantic Versioning](https://semver.org/).

## Unreleased

### Baseline

- `inspectra baseline create` records the current findings of a package in a committed
  `inspectra-baseline.json`, and `inspectra baseline prune` removes the fixed ones without ever adding
  any. `--only scan,lint,style,trivy` selects scopes, `--recursive` covers nested packages; a scope
  that cannot run completely exits with `69` and writes nothing.
- `scan`, `audit`, `typosquat`, `trivy`, `lint`, `style`, `check` and the `build_runner` builders leave
  out recorded findings. Entries are matched by scope, source, rule, package and file, without line
  numbers or package versions, and count their occurrences. `inspect`, `add` and `trust` do not use the
  baseline.
- The `baseline:` configuration section: `enabled`, `file`, `max_severity`, `fail_on_stale`; the
  public `BaselineConfig` and `BaselineSummary`, and the `baseline` field of `InspectraConfig`,
  `StyleResult`, `LintResult` and `ScanResult`.
- JSON: `baselined` in the reports of `scan` and `audit`, and `baseline` with `covered` and `stale` in
  the results of `lint`, `style` and the Trivy scans, present only when a baseline was applied.

### Configuration tools

- `inspectra config show` prints the effective configuration as YAML; `--explain` comments every
  value with its origin (file and line, environment variable, command line or default) and
  `--only-changed` leaves out the defaults. `-f json` lists `key`, `value`, `default`, `origin`,
  `variable` and `line` per option.
- `inspectra config validate` checks the configuration and that every file it refers to exists, and
  lists all problems at once (exit code `65`).
- `inspectra config lint` reports risky settings as findings of the new source `config`:
  `CONFIG_INSECURE_URL`, `CONFIG_UNKNOWN_VARIABLE`, `CONFIG_TRIVY_DISABLED`, `CONFIG_UNPINNED_TRIVY`,
  `CONFIG_IGNORE_EXPIRED`, `CONFIG_IGNORE_WITHOUT_EXPIRY`, `CONFIG_GATE_NOT_FAILING`,
  `CONFIG_MIN_SEVERITY`, `CONFIG_NO_COVERAGE_THRESHOLD` and `CONFIG_BASELINE_UNBOUNDED`.
- `inspectra config schema` prints the JSON Schema of `inspectra.yaml`, generated from the code and
  published as `inspectra.schema.json`; `inspectra.example.yaml` starts with its
  `yaml-language-server` modeline.
- Unknown keys in the configuration file, in `ignore` entries and on the command line name the closest
  valid option: `Did you mean "secret"?`.
- Library: `ConfigRecorder`, `ConfigEntry`, `ConfigKind`, `ConfigOrigin`, `ConfigOverride`,
  `ConfigOverrides.resolve` and `knownPaths`, a `recorder` parameter of `loadConfig`,
  `InspectraConfig.parse` and `InspectraConfig.fromSources`, and `FindingSource.config`.
- `trivy.filesystem.scanners` accepts scanner names in any case, like the severities.

### Fixed

- `trivy.executable` is a known option again while `INSPECTRA_TRIVY` is set: the key in the
  configuration file no longer fails as an unknown option, and `--trivy-executable` or
  `--set trivy.executable=…` now wins over `INSPECTRA_TRIVY` as the command line should.

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
- Style check (`inspectra style`, a step of `check`, the `inspectra:style` builder) with rules no lint
  covers: `license_header` from a template with `{year}`, `public_docs`, `private_docs`,
  `one_type_per_file`, `one_public_type_per_file`, `file_named_after_type`, `no_comments`,
  `no_else`, `no_default_case` and `no_wildcard_case`; the presets `none`, `recommended` (fits
  Flutter's widget-plus-private-`State` files) and `strict`, per-rule switches,
  `// inspectra: ignore-style` and `ignore-style-file` comments, and text, JSON, Markdown and SARIF
  output.
- Custom style rules: `package:inspectra/style.dart` with `StyleRule`, `StyleFile`, `StyleReporter`
  and `StyleChecker`; the files of `style.custom_rules` are run by a generated program through
  `dart run`, so they work with the compiled executable as well.
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
