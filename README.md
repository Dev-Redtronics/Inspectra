# Inspectra

**Inspectra** is software assurance and supply-chain security for Dart and Flutter, in one lightweight
CLI and one YAML configuration:

- **Supply-chain security** — OSV.dev vulnerability audit, static inspection of a package's published
  source before you add it, pub.dev trust assessment, typosquatting and dependency confusion
  detection, safe installation of exactly the audited version, a Git pre-commit hook. Everything
  [`dart_audit`](https://pub.dev/packages/dart_audit) does, with the same commands, flags, rule ids,
  JSON fields and exit codes, and without its correctness and security gaps.
- **Trivy** — secret, license, vulnerability, misconfiguration and filesystem scans. Inspectra finds
  an installed Trivy or **downloads a pinned, checksum-verified release for Linux, macOS and Windows —
  only when the network is available**. Version, mode and download are configurable.
- **Package quality gates** — format and lint checks, a style check with built-in house rules and
  **your own rules written in Dart**, a committed public API dump and a coverage gate, run from the
  command line or by `build_runner`.
- **Changelog** — the next release of `CHANGELOG.md` generated from Conventional Commits in the Keep a
  Changelog layout, a suggested semantic version, a CI check that every version is documented, and the
  release notes of a version. Built in, with no extra dependency: it reads the history with `git`.

It is the Dart counterpart of the static analysis, security and API features of
[Kreate](https://github.com/davils-com/kreate) for Gradle:

| Kreate (Gradle)                | Inspectra (Dart)                                                             |
|:-------------------------------|:-----------------------------------------------------------------------------|
| Detekt with `kreateRules`      | `inspectra lint`, `inspectra:lint` builder, `package:inspectra/lints/strict.yaml` |
| Detekt custom rule sets        | `inspectra style`, custom rules with `package:inspectra/style.dart`           |
| Formatting rules               | `inspectra format [--fix]`, `inspectra:format` builder                        |
| `kreateTrivySecretScan`        | `inspectra:secret_scan` builder, `inspectra trivy secret`                     |
| `kreateTrivyLicenseScan`       | `inspectra:license_scan` builder, `inspectra trivy license`                   |
| `kreateTrivyVulnerabilityScan` | `inspectra:vulnerability_scan` builder, `inspectra trivy vulnerability`       |
| `kreateApiDump` / `ApiCheck`   | `dart run build_runner build [--only-check]`, `inspectra api dump\|check`     |
| Kover threshold gate           | `inspectra coverage`                                                         |
| —                              | `inspectra scan`, `audit`, `inspect`, `trust`, `typosquat`, `add`, `hook`     |
| —                              | `inspectra changelog generate\|check\|notes`                                |

## Commands

| Command | What it does |
|---|---|
| `inspectra [scan]` | **Default.** OSV.dev audit + pubspec rules + typosquatting + dependency confusion + Trivy filesystem scan, one report (`-r` for monorepos) |
| `inspectra audit` | Checks every package of `pubspec.lock` against [OSV.dev](https://osv.dev) |
| `inspectra inspect <pkg> <version>` | Downloads, verifies and statically analyses a package's published source |
| `inspectra trust <pkg> [version]` | Trust assessment from pub.dev: age, release freshness, publisher, popularity |
| `inspectra typosquat` | Typosquatting and dependency confusion analysis of `pubspec.yaml` |
| `inspectra deps [--fix] [-r]` | Pubspec rules and the dependency policy, offline; `--fix` bounds constraints, moves dev packages and adds `publish_to: none` |
| `inspectra add <pkg> [version]` | Audits a package and adds **exactly** the audited version (`--dev`, `--dry-run`, `--force`) |
| `inspectra hook [install\|remove]` | Git pre-commit hook for staged `pubspec.yaml` / `pubspec.lock` changes |
| `inspectra trivy [secret\|license\|vulnerability\|filesystem…]` | The configured Trivy scans, or a `trivy fs` scan; `--install`, `--where` |
| `inspectra check` | Every enabled package check: format, lint, style, API, changelog, Trivy scans, coverage |
| `inspectra format [--fix]` / `lint [--fix]` | `dart format` / `dart analyze` gates |
| `inspectra style` | Built-in and custom style rules: license header, one type per file, documentation, no `else`, … (SARIF-capable) |
| `inspectra api dump\|check` | Record or verify the public API dump |
| `inspectra coverage [--min 80]` | Run the tests with coverage and check the threshold |
| `inspectra changelog generate [--write]` | The changelog section of the next release from Conventional Commits, with a suggested version (`--from`, `--to`, `--release`, `--date`) |
| `inspectra changelog check` | Fail when `CHANGELOG.md` is malformed or misses the version of `pubspec.yaml` |
| `inspectra changelog notes [version]` | Print the section of a release, for example as GitHub release notes |
| `inspectra config show\|validate\|lint\|schema` | Effective configuration with the origin of each value (`--explain`), validation of referenced files, risky settings, JSON Schema |
| `inspectra baseline create\|prune` | Record today's findings so that only new ones fail (`--only scan,lint,style,trivy`), or remove the fixed ones |

`-C <path>` before the command works on another package. The supply-chain commands share
`--format text|json|sarif|markdown`, `--output`, `--fail-on`, `--min-severity`, `--ignore`,
`--exit-zero`, `--offline`, `--config`, `--set key=value`, `--[no-]color`, `-q` and `-v`.

## Installation

```bash
dart pub global activate inspectra
inspectra --version
```

or as a dev dependency, which also enables the `build_runner` builders:

```yaml
dev_dependencies:
  build_runner: ^2.16.1
  inspectra: ^1.0.0
```

Native executables for Linux, macOS and Windows with SHA-256 checksums are attached to every
[GitHub release](https://github.com/davils-com/Inspectra/releases).

## Quick start

```bash
inspectra                                   # full supply-chain scan of the current project
inspectra scan -f sarif -o inspectra.sarif  # for GitHub code scanning
inspectra audit --format json               # dart_audit compatible JSON
inspectra inspect http 1.2.0                # vet a package before adding it
inspectra add http 1.2.0                    # ... and add exactly that version
dart run inspectra check                    # every enabled package gate
```

## Trivy provisioning

Every command that runs Trivy — `scan`, `trivy`, `check` — resolves it in this order:

1. `trivy.mode: disabled` — Trivy is never located, downloaded or run;
2. `trivy.executable` or the `INSPECTRA_TRIVY` environment variable — nothing else is considered;
3. an installed Trivy on the `PATH` or in a package manager directory (Homebrew, Scoop, WinGet,
   Chocolatey, `~/.local/bin`), whatever its version (`use_installed: true`);
4. a previously downloaded Trivy of the configured version in Inspectra's cache;
5. with `use_installed: false`, an installed Trivy of exactly the configured version;
6. **a download** of the configured version from the official GitHub release (or your mirror) — only
   when `download: true`, not in `--offline` mode, the download host answers within
   `connectivity_timeout` and Trivy publishes a build for the platform (Linux x64/arm64/arm/386,
   macOS x64/arm64, Windows x64/arm64).

The `build_runner` builders never download Trivy: they use `INSPECTRA_TRIVY`, then
`trivy.executable`, then `trivy` on the `PATH`; `inspectra trivy --install` provides one to put there.

Every download is verified against the release's `checksums.txt`; this check cannot be disabled, so an
unverified binary is never executed. The binary is installed atomically to
`<user cache>/inspectra/trivy/<version>/` and reused afterwards.

| Setting | Flag / variable | Default |
|---|---|---|
| `trivy.mode` (`auto`, `required`, `disabled`) | `--trivy-mode` | `auto`: skip with a warning when unavailable |
| `trivy.version` (exact or `latest`) | `--trivy-version`, `INSPECTRA_TRIVY_VERSION` | `0.75.0` |
| `trivy.download` | `--[no-]trivy-download` | `true` |
| `trivy.use_installed` | `--[no-]trivy-use-installed` | `true` |
| `trivy.executable` | `--trivy-executable`, `INSPECTRA_TRIVY` | – |
| `trivy.download_base_url` | `--set trivy.download_base_url=…` | GitHub releases |

```bash
inspectra trivy --where          # which Trivy would be used, and where it comes from
inspectra trivy --install        # make it available now, e.g. to warm a CI cache
```

Air-gapped environments point `download_base_url` at a mirror of the release assets and
`db_repository` at a mirror of the Trivy database, or set `skip_db_update: true` with a pre-seeded
`cache_directory`.

## Configuration

The configuration lives in the `inspectra:` section of `pubspec.yaml`, or in an `inspectra.yaml` next
to it with the same keys (without the `inspectra:` level); `inspectra.yaml` wins when both exist.
`--config <file>` or `INSPECTRA_CONFIG` name another file. Every option can be overridden — highest
precedence first:

1. `--set trivy.version=latest` and dedicated flags such as `--trivy-version`;
2. `INSPECTRA_<PATH>` environment variables, e.g. `INSPECTRA_TRIVY_VERSION`,
   `INSPECTRA_NETWORK_PROXY`, `INSPECTRA_TRIVY_FILESYSTEM_SCANNERS=vuln,secret`;
3. the configuration file;
4. built-in defaults.

Unknown keys and wrong types are errors that name the offending key and the closest valid one, for example
`Invalid Inspectra configuration at "inspectra.trivy.secrets": unknown option. Did you mean "secret"?`.
[`inspectra.example.yaml`](inspectra.example.yaml) lists every option with its default.

### Configuration tools

```bash
dart run inspectra config show --explain    # every effective value and where it comes from
dart run inspectra config validate          # the configuration and every file it refers to
dart run inspectra config lint              # risky settings, misspelled INSPECTRA_* variables
dart run inspectra config schema            # JSON Schema for completion in the editor
```

`config show --explain` comments each value with its origin - `inspectra.yaml:12`, `environment variable
INSPECTRA_TRIVY_MODE`, `command line` or `default` - and `--only-changed` shows only what a package configures.
`config lint` reports insecure service URLs, a disabled or unpinned Trivy, ignore rules without or past their expiry,
gates that never fail and `INSPECTRA_*` variables that name no option, as findings with `-f sarif` and `--fail-on`.
For completion and validation as you type, start `inspectra.yaml` with
`# yaml-language-server: $schema=https://raw.githubusercontent.com/davils-com/Inspectra/main/inspectra.schema.json`.

> **Note** — `pubspec.yaml` is always a `build_runner` source, so editing the section reruns the
> builders. `inspectra.yaml` and `trivy-secret.yaml` are not sources by default: list them under
> `targets.$default.sources` in your `build.yaml` if you want edits to rerun the builders.

### Ignoring findings

```yaml
ignore:
  - id: GHSA-xxxx-yyyy-zzzz          # or a CVE alias, or a rule id such as HARDCODED_URL
    package: http                    # optional
    reason: Not reachable in our usage.   # required
    expires: 2027-01-31              # optional; afterwards the rule stops matching
```

`--ignore <id>` (repeatable) works as in `dart_audit`. Trivy scans additionally have their own
`ignored_vulnerabilities`, `ignored_licenses` and `ignored_packages`.

### Dependency policy

```yaml
inspectra:
  dependency_policy:
    enabled: true
    denied: [{name: http_parser_legacy, reason: Unmaintained., replacement: http}]
    allowed_hosts: [https://pub.acme.corp, https://pub.dev]
    require_upper_bound: true
    min_sdk: 3.6.0
    dev_only: [mockito, build_runner, lints, test]
    require_publish_to: true
```

Organisation rules for dependencies, checked by `inspectra deps` (offline, `-r` for workspaces), `scan` and `check`:
denied packages (also transitive), allowed packages, registries and Git hosts, upper bounds, SDK minimums,
development packages in `dependencies`, a missing `publish_to` that would let `dart pub publish` upload an internal
package to pub.dev, required metadata, a `pubspec.lock` out of sync or without checksums, and unused or misplaced
dependencies found from the imports. `inspectra deps --fix` applies the fixable rules while keeping comments and
formatting. Every rule is opt-in.

### Baseline for existing code

```bash
dart run inspectra baseline create      # record today's findings in inspectra-baseline.json
dart run inspectra baseline prune       # remove the fixed ones; never adds anything
```

Introducing a gate into a code base that is years old no longer means fixing hundreds of findings first: commit the
baseline, and `scan`, `audit`, `typosquat`, `trivy`, `lint`, `style`, `check` and the builders report only findings
that are not recorded. Entries are matched by scope, source, rule, package and file, without line numbers or package
versions, and count their occurrences, so moving code does not make a finding new but a further occurrence does.
`--only scan,lint,style,trivy` selects scopes; a run that cannot complete (offline, Trivy unavailable) writes nothing.
`baseline.max_severity` keeps severe findings out of the baseline, `baseline.fail_on_stale` fails a check until fixed
findings are pruned, and `--set baseline.enabled=false` shows everything.

### Enterprise networks

Proxies come from `HTTPS_PROXY` / `HTTP_PROXY` / `NO_PROXY` or `network.proxy`; additional certificate
authorities from `network.ca_certificates`; private pub repositories from `PUB_HOSTED_URL`; an internal
OSV mirror from `network.osv_url`. `--offline` (or `network.offline: true`) makes Inspectra send no
HTTP request and download no Trivy, and starts Trivy with `--skip-db-update --offline-scan`, so Trivy
does not fetch its database either. Without a cached Trivy database the Trivy part of `scan` is then
skipped in `trivy.mode: auto` and exits with `69` in `required`.

## Output and exit codes

The supply-chain commands render `--format text|json|sarif|markdown`; progress goes to stderr, so
`inspectra audit -f json > report.json` always produces valid JSON. JSON documents carry
`schemaVersion`, `tool` and `generatedAt` and keep the `dart_audit` field names.

| Code | Meaning |
|---|---|
| `0` | Passed: no finding reached the threshold, every gate passed |
| `1` | Findings at or above `--fail-on` (default: any finding; `typosquat`: HIGH; `trust`: CRITICAL; `inspect`/`add`: risk score ≥ `inspect.fail_score`), or a failed gate |
| `64` | Invalid command line, or a Git revision, version or date the changelog cannot use |
| `65` | Invalid input: lockfile, pubspec, configuration, a changelog without the requested release |
| `69` | Incomplete: OSV.dev, pub.dev, Trivy, `git`, `dart` or the coverage tooling unavailable or failing |
| `70` | Internal error (`INSPECTRA_DEBUG=1` prints the stack trace) |

`--exit-zero` turns `1` into `0` and never hides `64`, `65`, `69` or `70`.

## Supply-chain checks

- **audit** — every hosted package of `pubspec.lock` against OSV.dev, with full advisory records,
  CVSS v3/v2 scoring, the fix for the installed version's range and an advisory cache. Git, path, SDK
  and private-registry packages are listed as not auditable.
- **inspect** — the archive is verified against its published SHA-256 and read in memory within size
  limits. Scanners: 16 pattern rules (process execution, shells, sockets, sensitive paths, obfuscation,
  crypto mining, backdoors, exfiltration, dynamic code loading, download-and-execute), string entropy,
  invisible/bidi/tag/homoglyph Unicode, archive structure (traversal, links, duplicates, native
  binaries, build hooks, setuid) and the package's own pubspec, plus the trust assessment. Tests,
  examples and tooling are skipped for code patterns because they never run in your app.
- **trust** — first publication, release freshness, retraction, discontinuation, verified publisher,
  likes, downloads and pub points, with configurable thresholds.
- **typosquat** — closest popular package by edit distance, `flutter_`/`dart_`/`pub_` wrapping,
  suspicious suffixes, private packages whose name also exists on pub.dev, inflated versions.
- **pubspec rules** (in `scan`) — unconstrained versions, Git dependencies on mutable branches, raw
  IPs or paste sites, plain HTTP sources, path dependencies, overrides, Dart 2 SDK constraints.

The pre-commit hook (`inspectra hook`) audits the **staged** `pubspec.lock` and checks the staged
`pubspec.yaml` of every package in the repository; it never overwrites a foreign hook and honours
`core.hooksPath` and worktrees.

## Package quality gates

### How it fits into build_runner

Inspectra's builders apply to the root package automatically and do nothing until a feature is enabled.
They read the configuration only from `pubspec.yaml` or `inspectra.yaml`: `--set` and the
`INSPECTRA_*` overrides do not apply to them, except `INSPECTRA_TRIVY`, which names the Trivy
executable.

- **`inspectra:format`** and **`inspectra:lint`** run `dart format` and `dart analyze` when the check
  is `enabled` and its `run_on_build` is set, after every code generator.
- **`inspectra:api`** writes the public API to `api/<package>.api` (`build_to: source`). The dump is
  committed, so every API change shows up as a diff in review. `build_runner build --only-check`
  fails when the committed dump differs — the API check for CI.
- **`inspectra:secret_scan`**, **`inspectra:license_scan`** and **`inspectra:vulnerability_scan`** run
  a scan when `trivy.enabled`, the scan's own `enabled` and its `run_on_build` are all set (by default
  `run_on_build` is set only for the secret scan). Findings are logged; with `fail_on_findings` they
  fail the build.

### Format and lint

The format check runs `dart format --output=none --set-exit-if-changed` over the selected files;
`--fix` formats them instead. The lint check runs `dart analyze` and fails from `fail_on`: `info` is
`--fatal-infos`, `warning` the analyzer's default, `error` only on errors, `none` never.
`package:inspectra/lints/strict.yaml` is a strict preset with strict casts, inference and raw types
and about 200 lint rules, which this repository uses itself.

### Style check

Rules no lint covers, on the syntax tree: `license_header` (from a template with `{year}`),
`one_public_type_per_file`, `one_type_per_file`, `file_named_after_type`, `public_docs`,
`private_docs`, `no_comments`, `no_else`, `no_default_case`, `no_wildcard_case`.
`preset: recommended` (the default) takes the header, one public type per file and file naming -
Flutter's widget-plus-private-`State` files pass; `strict` is the house style Inspectra follows
itself; `rules: {no_else: true}` switches single rules.
`// inspectra: ignore-style <rule>` suppresses a line, `ignore-style-file` a file.

Custom rules are Dart classes against the analyzer's syntax tree, written with
`package:inspectra/style.dart` and listed in `style.custom_rules`:

```dart
final styleRules = <StyleRule>[const NoPrintRule()];

final class NoPrintRule extends StyleRule {
  const NoPrintRule();
  @override
  String get id => 'no_print';
  @override
  String get description => 'Use a logger instead of print.';
  @override
  void check(StyleFile file, StyleReporter reporter) =>
      file.unit.accept(_PrintFinder(reporter));
}
```

Inspectra runs them in a generated program with `dart run`, so they work with the compiled
executable too, and reports them like its own rules. Inspectra holds itself to `strict`.

### Public API dump

Inspectra renders every public library — each file under `lib/` outside `lib/src/` — with everything
it declares or re-exports, sorted by name. Moving a declaration between files under `lib/src` does not
change the dump; changing a signature, a modifier, a default value or the value of a constant does.
Declarations annotated with `@internal` or `@visibleForTesting`, or any annotation listed in
`non_public_annotations`, are left out.

### Trivy scans

- **secret** — the selected files are copied into a temporary directory and scanned by one
  `trivy fs --scanners secret` run; `trivy-secret.yaml`, `trivy.yaml` and `.trivyignore` in the
  package root apply.
- **license** — Inspectra builds the dependency graph from `pubspec.lock`,
  `.dart_tool/package_config.json` and each dependency's `pubspec.yaml`, and hands the license files
  to Trivy's classifier. By default only what `dependencies` pull in is checked.
- **vulnerability** — Trivy matches `pubspec.lock` against the GitHub Security Advisories for pub.
- **filesystem** — a plain `trivy fs` of the package with `vuln`, `secret` and `misconfig` scanners;
  `scan` uses its scanners, severities and skipped directories too.

### Coverage gate

`inspectra coverage` runs `dart test --coverage` (or `flutter test --coverage`), merges the hit maps
with `package:coverage` — honouring `// coverage:ignore-line`, `ignore-start`/`ignore-end` and
`ignore-file` — writes `coverage/lcov.info` and fails below `min_line_coverage`.

## Changelog

```bash
dart run inspectra changelog generate            # preview the next release
dart run inspectra changelog generate --write    # add it to CHANGELOG.md
dart run inspectra changelog check               # CHANGELOG.md documents the version of pubspec.yaml
dart run inspectra changelog notes 1.2.0         # the section of 1.2.0, as release notes
```

Commits since the latest `v*` tag are grouped by their Conventional Commits type into **Added**,
**Changed**, **Deprecated**, **Removed**, **Fixed** and **Security**, with breaking changes (`feat!:`,
`BREAKING CHANGE:`) in a section of their own; `docs`, `test`, `ci`, `chore` and the like are hidden.
The version is suggested by Semantic Versioning (before `1.0.0`, a breaking change raises the minor
version), a higher version in `pubspec.yaml` wins, and `--release` overrides both. Reverted commits
are dropped together with their revert, commit texts are sanitised, and `--write` never touches
existing sections. With `changelog: {enabled: true}`, `inspectra check` runs the changelog check.
The mapping of types, the tag prefix and the link templates are configurable.

## Documentation

The full documentation lives in [`docs/`](docs/) as a [Writerside](https://www.jetbrains.com/writerside/)
project and is published to GitHub Pages from `main`.

## CI (GitHub Actions)

```yaml
steps:
  - uses: actions/checkout@v7
  - uses: dart-lang/setup-dart@v1
  - run: dart pub get
  - run: dart run inspectra scan -f sarif -o inspectra.sarif --fail-on high
  - uses: github/codeql-action/upload-sarif@v4
    if: always()
    with:
      sarif_file: inspectra.sarif
  - run: dart run build_runner build --only-check
  - run: dart run inspectra check
```

`scan` and `check` provision Trivy automatically. Trivy builders with `run_on_build` need it on the
`PATH`: run `dart run inspectra trivy --install --format json --output "$RUNNER_TEMP/trivy.json"` and
append the directory of its `trivy.executable` to `$GITHUB_PATH` before `build_runner`. Use
`-f markdown >> "$GITHUB_STEP_SUMMARY"` for a job summary.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and the binding rules in [AGENTS.md](AGENTS.md). One command
verifies everything:

```bash
dart run tool/verify.dart
```

## License

Apache 2.0 — see [LICENSE](LICENSE). Third-party software: [THIRDPARTY.md](THIRDPARTY.md).
