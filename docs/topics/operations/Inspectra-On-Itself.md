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
    vulnerability:
      run_on_build: true
    filesystem:
      enabled: true
      scanners: [vuln, secret, misconfig]
  coverage:
    enabled: true
    min_line_coverage: 85
```

- **Format and lint on every build**: an unformatted file or a single lint fails `build_runner build`, with
  `fail_on: info`.
- **Lint preset**: the repository's `analysis_options.yaml` is one line,
  `include: package:inspectra/lints/strict.yaml` - the preset Inspectra ships.
- **API**: `api/inspectra.api` records the public API of `package:inspectra/inspectra.dart` and
  `package:inspectra/builder.dart`.
- **All three focused scans on build**: every `build_runner build` runs the secret, license and vulnerability scans.
  The license and vulnerability scans cost nothing unless `pubspec.lock` changed.
- **Filesystem scan** in CI, for everything the focused scans do not cover.
- **Coverage gate** at 85%; the suite currently measures about 88%.

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

The `CI` workflow has three jobs:

| Job | Runs |
|:--|:--|
| Format and analyze | `dart run inspectra format` and `dart run inspectra lint`, with the strict lint preset |
| Test | `dart test` on Linux and macOS, with Trivy installed so the integration tests run against the real scanner |
| Inspectra on itself | `dart run build_runner build --only-check`, then `dart run inspectra check` - format, lint, API, all four scans, coverage; uploads `lcov.info` and the Trivy reports |

It also runs weekly, so a vulnerability published for one of Inspectra's dependencies is noticed without a push. The
`Documentation` workflow builds this documentation with Writerside, checks it, and deploys it to GitHub Pages from
`main`.

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
