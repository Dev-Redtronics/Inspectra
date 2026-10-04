# Inspectra on itself

<primary-label ref="guide"/>

<show-structure for="chapter" depth="2"/>

<link-summary>How the Inspectra repository uses every Inspectra feature on its own code.</link-summary>

<card-summary>A complete, working reference setup: configuration, build sources, secret rules and CI.</card-summary>

%product% checks itself with every feature it ships. Its repository is therefore a complete reference setup - every
file below is real and runs on every push.

## Configuration

```yaml
# pubspec.yaml
inspectra:
  format:
    enabled: true
    run_on_build: true
  lint:
    enabled: true
    run_on_build: true
  api:
    enabled: true
  trivy:
    enabled: true
    license:
      run_on_build: true
      # package:archive bundles a decoder under the permissive bzip2-1.0.6
      # license (BSD-style), which Trivy cannot classify.
      ignored_licenses: [bzip2]
    vulnerability:
      run_on_build: true
    filesystem:
      enabled: true
      scanners: [vuln, secret, misconfig]
  coverage:
    enabled: true
    min_line_coverage: 90
```

- **Format and lint on every build**: an unformatted file or a single lint fails `build_runner build`, with
  `fail_on: info`.
- **Lint preset**: the repository's `analysis_options.yaml` includes `package:inspectra/lints/strict.yaml` - the
  preset Inspectra ships - and tightens it further: `unawaited_futures`, `discarded_futures`,
  `public_member_api_docs`, `no_default_cases`, `exhaustive_cases` and `avoid_dynamic_calls` are errors, `build/` and
  `.dart_tool/` are excluded, and `avoid_catches_without_on_clauses`, `avoid_void_async`, `comment_references`,
  `literal_only_boolean_expressions`, `no_default_cases`, `public_member_api_docs` and `throw_in_finally` are enabled
  on top of the preset.
- **API**: `api/inspectra.api` records the public API of `package:inspectra/inspectra.dart` and
  `package:inspectra/builder.dart`.
- **License scan**: `ignored_licenses: [bzip2]` accepts the bzip2 decoder bundled by `package:archive`, whose
  BSD-style license Trivy cannot classify.
- **All three focused scans on build**: every `build_runner build` runs the secret, license and vulnerability scans.
  The license and vulnerability scans cost nothing unless `pubspec.lock` changed.
- **Filesystem scan** in CI, for everything the focused scans do not cover.
- **Coverage gate** at 90%; the suite currently measures about 90.6%.

## Build sources

```yaml
# build.yaml
targets:
  $default:
    sources:
      - $package$
      - lib/**
      - bin/**
      - test/**
      - example/**
      - .github/**
      - pubspec.yaml
      - pubspec.lock
      - build.yaml
      - analysis_options.yaml
      - dart_test.yaml
      - trivy-secret.yaml
      - README.md
      - CHANGELOG.md
```

The extra sources let the secret builder scan the workflow files and the root-level configuration, and make an edit to
`trivy-secret.yaml` rerun the scan. See [Build sources](Build-Sources.md).

## Secret rules

```yaml
# trivy-secret.yaml
disable-allow-rules:
  - usr-dirs

rules:
  - id: dart-hardcoded-credential
    category: Dart
    title: Hard-coded credential in Dart source
    severity: HIGH
    regex: (?i)(api_?key|token|secret|password)\s*=\s*['"](?P<secret>[A-Za-z0-9_/+\-]{8,})['"]
    secret-group-name: secret
    keywords:
      - apikey
      - api_key
      - token
      - secret
      - password
```

The built-in allow rule for test directories stays on: Inspectra's own tests contain deliberately fake tokens to test
the secret scan.

## CI

Four workflows run in GitHub Actions. Every action is pinned to a commit SHA, and every job starts with no
permissions beyond the ones it declares.

### CI

The `CI` workflow runs on every push, on pull requests to `main` and `develop`, and weekly, so a vulnerability
published for one of Inspectra's dependencies is noticed without a push. It has three jobs:

| Job | Runs |
|:--|:--|
| `verify` | `dart run tool/verify.dart` - format, analyze, style check and tests - on Linux, macOS and Windows with the stable SDK, and on Linux with the minimum SDK %min_dart% |
| `inspectra` | `dart run build_runner build --only-check`, then `dart run inspectra check` - format, lint, API, every enabled scan and the coverage gate; uploads `lcov.info` and the Trivy reports |
| `compile` | `dart compile exe bin/inspectra.dart` on Linux, macOS and Windows, then runs the executable with `--version` |

Neither `verify` nor `inspectra` uses a third-party action to install Trivy: Inspectra provisions it - checksum
verified - and puts its directory on the `PATH`:

```yaml
- name: Provision Trivy with Inspectra
  if: runner.os != 'Windows'
  run: |
    dart run bin/inspectra.dart trivy --install --format json --output "$RUNNER_TEMP/trivy.json"
    dirname "$(jq -r .trivy.executable "$RUNNER_TEMP/trivy.json")" >> "$GITHUB_PATH"
```

In `verify`, Trivy is provisioned on Linux and macOS only, so the integration tests tagged `trivy` run against the
real scanner there and are skipped on Windows. Trivy goes on the `PATH` rather than into `%trivy_env%`, which would
override the fake Trivy executables the unit tests configure. The `inspectra` job provisions it the same way, because
the Trivy builders and the integration tests in the coverage run need it on the `PATH`. Both jobs cache
`~/.cache/trivy`, the Trivy database.

### Security

The `Security` workflow runs on the same triggers and lets %product% scan itself with `scan --trivy-mode required`:
Trivy is downloaded and verified by %product% itself, and a missing Trivy fails the job. It uploads the result as
SARIF to GitHub code scanning, writes a Markdown report to the job summary, and finally fails on `HIGH` or `CRITICAL`
findings with `scan --fail-on high`. The SARIF and summary steps use `--exit-zero`, so a newly disclosed advisory
never prevents the upload.

### Release

The `Release` workflow runs for `v*` tags. It runs `tool/verify.dart`, checks that the tag matches the `version` of
`pubspec.yaml`, compiles native executables for Linux x64 and ARM64, macOS ARM64 and x64, and Windows x64, and
publishes them as zip archives with a `checksums.txt` of their SHA-256 sums in a GitHub release.

### Documentation

The `Documentation` workflow builds this documentation with Writerside when `docs/` changes, checks it for broken
links and other build errors, and deploys it to GitHub Pages from `main`.

<seealso>
    <category ref="operations">
        <a href="CI-Integration.md">CI integration</a>
    </category>
    <category ref="config">
        <a href="Configuration-Reference.md">Configuration reference</a>
        <a href="Build-Sources.md">Build sources</a>
    </category>
    <category ref="external">
        <a href="%repo%">The Inspectra repository</a>
    </category>
</seealso>
