# Inspectra

Supply-chain security scanner for Dart and Flutter projects — dependency vulnerabilities, package
source inspection, trust and typosquatting analysis, safe dependency installation, Git hooks and
[Trivy](https://github.com/aquasecurity/trivy), in one lightweight CLI.

Inspectra does everything [`dart_audit`](https://pub.dev/packages/dart_audit) does, with the same
commands, flags, rule ids, JSON fields and exit codes, and fixes its correctness and security gaps
(see the [changelog](CHANGELOG.md)).

| Command | What it does |
|---|---|
| `inspectra [scan]` | **Default.** OSV.dev audit + pubspec rules + typosquatting + dependency confusion + Trivy, in one report |
| `inspectra audit` | Checks every package of `pubspec.lock` against [OSV.dev](https://osv.dev) |
| `inspectra inspect <pkg> <version>` | Downloads, verifies and statically analyses a package's published source |
| `inspectra trust <pkg> [version]` | Trust assessment from pub.dev: age, release freshness, publisher, popularity |
| `inspectra typosquat` | Typosquatting and dependency confusion analysis of `pubspec.yaml` |
| `inspectra add <pkg> [version]` | Audits a package and adds **exactly** the audited version |
| `inspectra hook [install\|remove]` | Git pre-commit hook for staged `pubspec.yaml` / `pubspec.lock` changes |
| `inspectra trivy [dir]` | Runs Trivy (vulnerabilities, secrets, misconfigurations, licenses) |

---

## Installation

```bash
dart pub global activate inspectra
inspectra --version
```

or as a development dependency (`dart run inspectra`):

```yaml
dev_dependencies:
  inspectra: ^1.0.0
```

Native executables for Linux, macOS and Windows are attached to every
[GitHub release](https://github.com/Dev-Redtronics/inspectra/releases), with SHA-256 checksums.

## Quick start

```bash
inspectra                                   # full scan of the current project
inspectra scan --recursive                  # every package of a monorepo / pub workspace
inspectra scan -f sarif -o inspectra.sarif  # for GitHub code scanning
inspectra audit --format json               # dart_audit compatible JSON
inspectra inspect http 1.2.0                # vet a package before adding it
inspectra add http 1.2.0                    # ... and add exactly that version
```

## Trivy integration

`scan` and `trivy` run Trivy's file system scanners next to Inspectra's own checks. Trivy is
resolved in this order:

1. `trivy.executable`, if configured — nothing else is considered;
2. an installed Trivy on the `PATH` or in a package manager directory (Homebrew, Scoop, WinGet,
   Chocolatey, `~/.local/bin`), whatever its version (`useInstalled: true`);
3. a previously downloaded Trivy of the configured version in Inspectra's cache;
4. **a download** of the configured version from the official GitHub release (or your mirror) —
   only when `download: true`, not in `--offline` mode, the download host answers within
   `connectivityTimeout` and Trivy publishes a build for the platform (Linux x64/arm64/arm/386,
   macOS x64/arm64, Windows x64/arm64).

Every download is verified against the release's `checksums.txt`; this check cannot be disabled,
so an unverified binary is never executed. The binary is installed atomically to
`<user cache>/inspectra/trivy/<version>/` and reused afterwards.

| Setting | Flag | Default |
|---|---|---|
| `trivy.mode` (`auto`, `required`, `disabled`) | `--trivy-mode` | `auto`: skip with a warning when unavailable |
| `trivy.version` (exact or `latest`) | `--trivy-version` | `0.75.0` |
| `trivy.download` | `--[no-]trivy-download` | `true` |
| `trivy.useInstalled` | `--[no-]trivy-use-installed` | `true` |
| `trivy.executable` | `--trivy-executable` | – |
| `trivy.downloadBaseUrl` | `--set trivy.downloadBaseUrl=…` | GitHub releases |

```bash
inspectra trivy --where          # which Trivy would be used, and where it comes from
inspectra trivy --install        # make it available now, e.g. to warm a CI cache
```

With `mode: required` a missing Trivy fails the run with exit code `69`. Air-gapped environments
point `downloadBaseUrl` at a mirror of the release assets and `dbRepository` at a mirror of the
Trivy database, or set `skipDbUpdate: true` with a pre-seeded `cacheDirectory`.

## Configuration

Everything can be configured in `inspectra.yaml` (see [`inspectra.example.yaml`](inspectra.example.yaml)),
through environment variables and on the command line. Precedence, highest first:

1. `--set key=value` and dedicated flags such as `--trivy-version`;
2. `INSPECTRA_<SECTION>_<KEY>`, e.g. `INSPECTRA_TRIVY_VERSION=latest`,
   `INSPECTRA_NETWORK_PROXY=http://proxy:3128`;
3. `inspectra.yaml` (or `--config <file>`, or `INSPECTRA_CONFIG`);
4. built-in defaults.

Unknown keys and invalid values are rejected with exit code `65` and a message naming their origin.

### Ignoring findings

```yaml
ignore:
  - id: GHSA-xxxx-yyyy-zzzz          # or a CVE alias, or a rule id such as HARDCODED_URL
    package: http                    # optional
    reason: Not reachable in our usage.   # required
    expires: 2027-01-31              # optional; afterwards the rule stops matching
```

`--ignore <id>` (repeatable) works as in `dart_audit`.

### Enterprise networks

Proxies are taken from `HTTPS_PROXY` / `HTTP_PROXY` / `NO_PROXY` or `network.proxy`; additional
certificate authorities from `network.caCertificates`; private pub repositories from
`PUB_HOSTED_URL`; an internal OSV mirror from `network.osvUrl`. `--offline` guarantees that no
connection is opened at all.

## Output and exit codes

`--format text|json|sarif|markdown`, `--output <file>`. Progress goes to stderr, so
`inspectra audit -f json > report.json` always produces valid JSON. JSON documents carry
`schemaVersion`, `tool` and `generatedAt` and keep the `dart_audit` field names.

| Code | Meaning |
|---|---|
| `0` | No finding reached the failure threshold |
| `1` | Findings at or above `--fail-on` (default: any finding; `typosquat`: HIGH; `trust`: CRITICAL; `inspect`/`add`: risk score ≥ `inspect.failScore`) |
| `64` | Invalid command line |
| `65` | Invalid input: lockfile, pubspec, configuration |
| `69` | Verification incomplete: OSV.dev, pub.dev or a required Trivy unavailable |
| `70` | Internal error (`INSPECTRA_DEBUG=1` prints the stack trace) |

`--exit-zero` turns `1` into `0` and never hides `64`, `65`, `69` or `70`.

## What is checked

- **audit** — every hosted package of `pubspec.lock` against OSV.dev, with full advisory records,
  CVSS v3/v2 scoring, the fix for the installed version's range and an advisory cache. Git, path,
  SDK and private-registry packages are listed as not auditable.
- **inspect** — the archive is verified against its published SHA-256 and read in memory within
  size limits. Scanners: 16 pattern rules (process execution, shells, sockets, sensitive paths,
  obfuscation, crypto mining, backdoors, exfiltration, dynamic code loading, download-and-execute),
  string entropy, invisible/bidi/tag/homoglyph Unicode, archive structure (traversal, links,
  duplicates, native binaries, build hooks, setuid) and the package's own pubspec, plus the trust
  assessment. Tests, examples and tooling are skipped for code patterns because they never run in
  your app.
- **trust** — first publication, release freshness, retraction, discontinuation, verified
  publisher, likes, downloads and pub points, with configurable thresholds.
- **typosquat** — closest popular package by edit distance, `flutter_`/`dart_`/`pub_` wrapping,
  suspicious suffixes, private packages whose name also exists on pub.dev, inflated versions.
- **pubspec rules** (in `scan`) — unconstrained versions, Git dependencies on mutable branches, raw
  IPs or paste sites, plain HTTP sources, path dependencies, overrides, Dart 2 SDK constraints.

## CI

```yaml
- uses: dart-lang/setup-dart@v1
- run: dart pub global activate inspectra
- run: dart pub get
- run: inspectra scan -f sarif -o inspectra.sarif --fail-on high
- uses: github/codeql-action/upload-sarif@v4
  if: always()
  with:
    sarif_file: inspectra.sarif
```

Use `-f markdown >> "$GITHUB_STEP_SUMMARY"` for a job summary.

## Pre-commit hook

```bash
inspectra hook          # install
inspectra hook remove   # remove (only a hook installed by Inspectra)
```

The hook audits the **staged** `pubspec.lock` and checks the staged `pubspec.yaml` of every package
in the repository. It never overwrites a foreign hook and honours `core.hooksPath` and worktrees.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and the binding rules in [AGENTS.md](AGENTS.md). One command
verifies everything:

```bash
dart run tool/verify.dart
```

## License

Apache 2.0 — see [LICENSE](LICENSE). Third-party software: [THIRDPARTY.md](THIRDPARTY.md).
