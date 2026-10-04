# Coming from Kreate

<primary-label ref="guide"/>

<show-structure for="chapter" depth="2"/>

<link-summary>How Kreate's Trivy, API validation and coverage features map to Inspectra for Dart.</link-summary>

<card-summary>The same security, API and coverage features, the Dart way: builders instead of Gradle tasks.</card-summary>

%product% brings the security and compliance, binary compatibility validation and coverage features of
[Kreate](%kreate%), the Gradle plugin for Kotlin, to Dart. The ideas are the same; the mechanics follow the Dart
toolchain. This page maps one to the other.

## Concepts

| Kreate | %product% | Note |
|:--|:--|:--|
| Gradle plugin, `kreate { }` DSL | Dev dependency, `%pubspec_key%:` section in `pubspec.yaml` | One declarative configuration in both |
| Gradle tasks | `build_runner` builders and `dart run %package%` commands | |
| `check` lifecycle task | `dart run build_runner build`, `dart run %package% check` | |
| Opt-in features | Opt-in features | Nothing runs until enabled, in both |

## Static analysis and formatting

| Kreate | %product% |
|:--|:--|
| `detekt { enabled = true }` | `lint: { enabled: true }` |
| Detekt task on `check` | `dart run %package% lint`, `check`, or the `inspectra:lint` builder |
| `kreateRules` (Kreate's own Detekt rules) | `include: package:inspectra/lints/strict.yaml` |
| Detekt configuration file | `analysis_options.yaml` |
| Detekt reports | `.dart_tool/inspectra/lint.json` |
| ktlint / formatting rules | `format: { enabled: true }`, backed by `dart format` |

Dart has one analyzer and one formatter, both in the SDK, so there is nothing to apply or version: the checks enforce
what `dart analyze` and `dart format` already do.

## Security and compliance

| Kreate | %product% |
|:--|:--|
| `trivy { enabled = true }` | `trivy: { enabled: true }` |
| `kreateTrivyScan` | `dart run %package% trivy` |
| `kreateTrivySecretScan` | `inspectra:secret_scan` builder, `dart run %package% trivy secret` |
| `secrets { runOnCheck = true }` | `secret: { run_on_build: true }` |
| `secrets { sourceFiles.setFrom(...) }` | `secret: { include: [...], exclude: [...] }` |
| `secrets { secretConfig = ... }` | `secret: { config: ... }` |
| `kreateTrivyLicenseScan` | `inspectra:license_scan` builder, `dart run %package% trivy license` |
| `license { failOnForbidden = true }` | `license: { fail_on_findings: true }` |
| `license { ignoredLicenses }` | `license: { ignored_licenses: [...] }` |
| `license { configurations }` (production classpaths) | `license: { include_dev_dependencies: false }` (default) |
| `kreateTrivyVulnerabilityScan` | `inspectra:vulnerability_scan` builder, `dart run %package% trivy vulnerability` |
| `vulnerability { score }` | `vulnerability: { severity: [...] }` |
| `lockFiles` from `gradle.lockfile` | `pubspec.lock`, always present in Dart |
| - | `dart run %package% trivy filesystem` with misconfiguration scanning |

Differences worth knowing:

- **No lock file setup.** Kreate scans Gradle lock files that have to be written first. Pub always writes
  `pubspec.lock`, so the vulnerability scan needs no preparation.
- **Licenses come from license files.** Gradle lock files carry no licenses either; for Dart, %product% reads each
  shipped package's license file and lets Trivy classify it. See [License scan](Trivy-License-Scan.md).
- **The default secret rules are Trivy's full set.** Kreate's sample `trivy-secret.yaml` limited the built-in rules to
  AWS with `enable-builtin-rules`. %product%'s own `trivy-secret.yaml` keeps all built-in rules and adds one for Dart.
  See [Secret rules](Trivy-Secret-Rules.md).
- **One Trivy process per scan.** Kreate's secret scan runs Trivy per file; %product% stages the selected files and
  scans them in one run.
- **Explicit errors.** Trivy failing is exit code `2` with Trivy's message, never a pass.

## API validation

| Kreate | %product% |
|:--|:--|
| `apiValidation { enabled = true }` | `api: { enabled: true }` |
| `kreateApiDump` | `dart run build_runner build`, or `dart run %package% api dump` |
| `kreateApiCheck` on `check` | `dart run build_runner build --only-check`, or `dart run %package% api check` |
| `api/<project>.api` | `api/<package>.api` |
| `apiDirectory`, `dumpFileName` | `output` |
| `nonPublicMarkers` | `non_public_annotations` |
| `ignoredPackages`, `ignoredClasses` | `ignored_libraries`, or annotations |
| JVM bytecode, descriptors | Dart source-level API, Dart syntax |

The biggest difference is what a dump records. A JVM has a binary interface, so Kreate dumps descriptors read from
class files. Dart packages are compiled together with their consumers, so what breaks a consumer is the source-level
API: %product% records signatures, default values and constant values in Dart syntax.

The workflow differs too: Kreate fails `check` when the dump is outdated, and you run `kreateApiDump`. %product%'s
builder updates the dump on every build and logs the diff; CI uses `--only-check`. Reviewers see the change either way.

## Coverage

| Kreate | %product% |
|:--|:--|
| `coverage { enabled = true }` (Kover) | `coverage: { enabled: true }` (`package:coverage`) |
| `verify { minLineCoverage = 80 }` | `min_line_coverage: 80` |
| Filters | `report_on`, `exclude`, `coverage:ignore` comments |
| XML and HTML reports | `lcov.info`, which every tool reads; `genhtml` for HTML |
| No default threshold | No default threshold |

## Not in Inspectra

Kreate's platform, JNI, C-interop, documentation, publishing, benchmark, dependency locking and local development
features have no counterpart: the Dart toolchain covers them itself (`dart pub publish`, `dart pub get` and `pubspec.lock`, FFI) or they
are outside %product%'s scope.

<seealso>
    <category ref="start">
        <a href="Overview.md">Overview</a>
        <a href="Getting-Started.md">Getting started</a>
    </category>
    <category ref="external">
        <a href="%kreate%">Kreate</a>
    </category>
</seealso>
