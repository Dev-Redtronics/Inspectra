# Inspectra

**Inspectra** brings security scanning, public API validation and a coverage gate to Dart packages,
configured in one YAML file and run by `build_runner`.

It is the Dart counterpart of the security and API features of
[Kreate](https://github.com/davils-com/kreate) for Gradle:

| Kreate (Gradle)                          | Inspectra (Dart)                                         |
|:-----------------------------------------|:---------------------------------------------------------|
| `kreateTrivySecretScan`                  | `inspectra:secret_scan` builder, `inspectra trivy secret` |
| `kreateTrivyLicenseScan`                 | `inspectra:license_scan` builder, `inspectra trivy license` |
| `kreateTrivyVulnerabilityScan`           | `inspectra:vulnerability_scan` builder, `inspectra trivy vulnerability` |
| —                                        | `inspectra trivy filesystem` (plain `trivy fs`, incl. misconfig) |
| `kreateApiDump`                          | `dart run build_runner build`, `inspectra api dump`       |
| `kreateApiCheck`                         | `dart run build_runner build --only-check`, `inspectra api check` |
| Kover threshold gate                     | `inspectra coverage` (via `package:coverage`)             |

Everything is opt-in. Adding Inspectra as a dev dependency changes nothing until a feature is enabled.

## Documentation

The full documentation lives in [`docs/`](docs/) as a [Writerside](https://www.jetbrains.com/writerside/) project and
is published to GitHub Pages from `main`: every option, every builder and command, the dump format, the secret rules,
CI pipelines and troubleshooting. To build it locally, open `docs/` with the Writerside plugin, or run the builder
image the `Documentation` workflow uses:

```bash
docker run --rm -v "$PWD:/github/workspace" -w /github/workspace \
  jetbrains/writerside-builder:2026.04.8711 /bin/bash -c \
  "Xvfb :99 & DISPLAY=:99 /opt/builder/bin/idea.sh helpbuilderinspect \
   --source-dir /github/workspace --product docs/d --runner github --output-dir artifacts/"
```

## Requirements

- Dart SDK 3.13 or later
- [Trivy](https://trivy.dev/latest/getting-started/installation/) on the `PATH` for the scans
  (or set `trivy.executable`, or the `INSPECTRA_TRIVY` environment variable)

Beyond Trivy, Inspectra uses only what the Dart toolchain ships with: the `analyzer` for the API dump,
`build` for the `build_runner` integration and `coverage` for the coverage gate.

## Getting started

```yaml
# pubspec.yaml
dev_dependencies:
  build_runner: ^2.16.1
  inspectra: ^1.0.0

inspectra:
  api:
    enabled: true
  trivy:
    enabled: true
  coverage:
    enabled: true
    min_line_coverage: 80
```

```bash
dart run build_runner build               # writes api/<package>.api, runs the secret scan
dart run build_runner build --only-check  # CI: fails when the committed API dump is outdated
dart run inspectra check                  # CI: every enabled check, build_runner not needed
```

## How it fits into build_runner

Inspectra's builders apply to the root package automatically.

- **`inspectra:api`** writes the public API to `api/<package>.api` (`build_to: source`). The dump is
  committed, so every API change shows up as a diff in review, and the build logs that diff as a
  warning. `build_runner build --only-check` writes nothing and fails when the committed dump differs
  — the API check for CI.
- **`inspectra:secret_scan`**, **`inspectra:license_scan`** and **`inspectra:vulnerability_scan`**
  run the scans whose `run_on_build` is set (by default only the secret scan, which needs no
  database download). Every file a scan reads goes through `build_runner`, so a scan reruns exactly
  when its input changes. Findings are logged; with `fail_on_findings` they fail the build. The JSON
  report lands in `.dart_tool/build/generated/<package>/inspectra/trivy/`.

The `inspectra` command line runs the same checks straight from the filesystem, which is what a CI
job usually wants:

```text
dart run inspectra check                     every enabled check
dart run inspectra api dump | check          record or verify the API dump
dart run inspectra trivy [secret|license|vulnerability|filesystem ...]
dart run inspectra coverage [--min 80]
dart run inspectra -C path/to/package ...    inspect another package
```

Exit codes: `0` passed, `1` a check failed, `2` broken configuration or tool, `64` usage error.

## Configuration

The configuration lives in the `inspectra:` section of `pubspec.yaml`, or in an `inspectra.yaml` next
to it with the same keys (without the `inspectra:` level). `inspectra.yaml` wins when both exist.

Unknown keys and wrong types are errors that name the offending key, for example
`Invalid Inspectra configuration at "inspectra.trivy.secrets": unknown option`.

> **Note** — `pubspec.yaml` is always a `build_runner` source, so editing the section reruns the
> builders. `inspectra.yaml` and `trivy-secret.yaml` are not sources by default: list them under
> `targets.$default.sources` in your `build.yaml` if you use them with `build_runner` and want edits
> to rerun the builders. The command line always reads the current files.

All options with their defaults:

```yaml
inspectra:
  api:
    enabled: false
    output: api/<package>.api           # the committed dump
    ignored_libraries: []               # globs, e.g. [lib/testing.dart]
    non_public_annotations: [internal, visibleForTesting]

  trivy:
    enabled: false
    executable: trivy                   # INSPECTRA_TRIVY overrides it
    report_directory: .dart_tool/inspectra/trivy   # JSON reports of the command line

    secret:
      enabled: true
      run_on_build: true
      fail_on_findings: true
      severity: [CRITICAL, HIGH, MEDIUM, LOW]
      config: trivy-secret.yaml         # used when present; required when set explicitly
      include: ['**.dart', '**.yaml', '**.yml', '**.json', '**.env', '**.properties']
      exclude: ['**/.dart_tool/**', '**/build/**', '**/.git/**']

    license:
      enabled: true
      run_on_build: false
      fail_on_findings: true
      severity: [CRITICAL, HIGH, UNKNOWN]
      ignored_licenses: []              # SPDX ids, e.g. [LGPL-3.0]
      ignored_packages: []
      include_dev_dependencies: false

    vulnerability:
      enabled: true
      run_on_build: false
      fail_on_findings: true
      severity: [CRITICAL, HIGH, MEDIUM, LOW]
      include_dev_dependencies: true
      ignore_unfixed: false
      ignored_vulnerabilities: []       # CVE or GHSA ids

    filesystem:                         # command line only
      enabled: false
      fail_on_findings: true
      severity: [CRITICAL, HIGH, MEDIUM, LOW]
      scanners: [vuln, secret, misconfig]   # also: license
      skip_dirs: [.dart_tool, build, .git]

  coverage:
    enabled: false
    runner: dart                        # or flutter
    output_directory: coverage          # lcov.info and the raw hit maps
    report_on: [lib]
    exclude: ['**.g.dart', '**.freezed.dart', '**.mocks.dart']
    min_line_coverage:                  # unset: report only; measure first, then set it
    test_arguments: []                  # e.g. [--exclude-tags, slow]
```

## Details

### Public API dump

The API of a Dart library is its export namespace. Inspectra renders every public library — each
file under `lib/` outside `lib/src/` — with everything it declares or re-exports, sorted by name, and
each class, mixin, enum, extension and extension type with its public members:

```text
library package:my_package/my_package.dart

abstract base class Shape<T extends num> with Named implements Comparable<Shape<T>> {
  static int count;
  final T size;
  Shape<T>(T size, {String label = 'shape'});
  const factory Shape<T>.empty();
  abstract double area();
  bool operator ==(Object other);
}

const String defaultLabel = 'shape';

@Deprecated int plus(int a, int b);
```

Moving a declaration between files under `lib/src` does not change the dump; changing a signature,
a modifier, a default value or the value of a constant does. When it changes, the build logs a
unified diff of exactly the lines that changed. Declarations annotated with `@internal` or `@visibleForTesting`
(from `package:meta`), or any annotation listed in `non_public_annotations`, are left out.

### Secret scan

The selected files are copied into a temporary directory and scanned by one `trivy fs --scanners
secret` run, so Trivy sees exactly the configured selection. Trivy reads `trivy-secret.yaml`,
`trivy.yaml` and `.trivyignore` from the package root. This repository's
[`trivy-secret.yaml`](trivy-secret.yaml) shows a custom rule for credentials in Dart sources.

Trivy's built-in allow rules skip `test/`, `tests/`, `testdata/`, `integration_test/`, `example/`,
`examples/` and Markdown files. `example/` is published with your package, so consider turning them
off with `disable-allow-rules` in `trivy-secret.yaml` and allowing your real fixtures explicitly.

### License scan

`pubspec.lock` carries no license information, so Inspectra builds the dependency graph from
`pubspec.lock`, `.dart_tool/package_config.json` and each dependency's `pubspec.yaml`, and hands the
license files of the resolved packages to Trivy's license classifier (`--license-full`).

- Only packages fetched from pub.dev or git are checked; path and SDK packages are your own code or
  the toolchain's.
- By default only what `dependencies` pull in is checked. A license binds what you ship, and a package
  only `dev_dependencies` need never reaches a consumer.
- Trivy maps license categories to severities: `forbidden` is `CRITICAL`, `restricted` `HIGH`,
  `reciprocal` `MEDIUM`, `notice`/`permissive` `LOW`. A package without a license file, or with one
  Trivy cannot classify, is reported as `UNKNOWN`.

### Vulnerability scan

Trivy reads `pubspec.lock` natively and matches it against the GitHub Security Advisories for pub.
With `include_dev_dependencies: false` the lock file is narrowed to the shipped dependencies first.
The scan downloads the Trivy database; in CI, cache `~/.cache/trivy` or set Trivy's own environment
variables (`TRIVY_CACHE_DIR`, `TRIVY_DB_REPOSITORY`, `TRIVY_SKIP_DB_UPDATE`, …), which Inspectra
passes through.

### Coverage gate

`inspectra coverage` runs `dart test --coverage` (or `flutter test --coverage`), merges the hit maps
with `package:coverage` — honouring `// coverage:ignore-line`, `ignore-start`/`ignore-end` and
`ignore-file` — writes `coverage/lcov.info` and fails below `min_line_coverage`. The VM only reports
libraries a test loaded, so files under `report_on` that no test imports are listed separately
instead of being silently left out.

## CI example (GitHub Actions)

```yaml
jobs:
  inspect:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
      - uses: aquasecurity/setup-trivy@v0.3.1
      - run: dart pub get
      - run: dart run build_runner build --only-check
      - run: dart run inspectra check
```

## License

See the repository for license information.
