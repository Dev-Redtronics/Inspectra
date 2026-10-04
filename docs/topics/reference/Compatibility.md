# Compatibility

<primary-label ref="guide"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Supported Dart, build_runner, Trivy and platform versions, and what CI verifies.</link-summary>

<card-summary>The versions Inspectra requires, the versions it is tested with, and the platforms CI covers.</card-summary>

| Component | Required | Tested in CI |
|:--|:--|:--|
| Dart SDK | %min_dart% | The stable channel on Linux, macOS and Windows, and %min_dart% on Linux; locally %tested_dart% |
| `build_runner` | %min_build_runner%, for `--only-check` | %min_build_runner% |
| Trivy | A release with `--scanners` | %tested_trivy%, the version %product% downloads by default |
| Flutter | Any release bundling Dart %min_dart%+ | Not in CI |

## Dart SDK

%product% requires Dart %min_dart% or later, as stated in its `pubspec.yaml`. It uses the analyzer's current element
model, which needs a recent SDK. CI runs the full verification - format, analysis, style check and tests - with the
current stable SDK and with %min_dart%, the minimum.

## Dependencies

| Package | Version | Used for |
|:--|:--|:--|
| `analyzer` | ^%analyzer_version% | Resolving libraries for the API dump |
| `build` | ^%build_version% | The builders |
| `coverage` | ^%coverage_version% | Merging hit maps, ignore comments, lcov |
| `archive` | ^4.0.7 | Reading package archives and the Trivy download in memory |
| `args` | ^2.7.0 | The command line |
| `crypto` | ^3.0.6 | SHA-256 verification of package archives and Trivy downloads, finding fingerprints |
| `glob` | ^2.2.0 | `include`, `exclude`, `ignored_libraries` |
| `path` | ^1.9.1 | Paths on every platform |
| `pub_semver` | ^2.2.0 | Version constraints and ranges of the supply-chain checks |
| `yaml` | ^3.1.4 | Reading the configuration |

HTTP uses `dart:io`, so %product% needs no HTTP client package.

<note>
<code>analyzer</code> is also a dependency of <code>build_runner</code>, <code>freezed</code>,
<code>json_serializable</code> and most code generators. If <code>dart pub get</code> cannot resolve, the cause is
usually one of them pinning an older <code>analyzer</code> major version; upgrading it is the fix.
</note>

## build_runner

`build_runner build --only-check`, the API check of the builder, was introduced in `build_runner` 2.16.0. With older
versions, the builders run, but CI has to use `dart run %package% api check` instead.

## Trivy

%product% uses Trivy's stable command line and reads the `Results` array of its JSON report. It is tested with Trivy
%tested_trivy%, the version pinned in %product% itself (`TrivyConfig.pinnedVersion`): the one it downloads unless
`trivy.version` says otherwise, and the one its CI provisions. Dart support - pub lock files and the GitHub advisories
for pub - has been in Trivy for many releases.

## Git {id="git"}

`changelog generate` reads the history with the `git` command line, which must be on the `PATH`. It needs Git 2.15 or
later for `rev-parse --is-shallow-repository`. %product% passes its own settings for signatures, colours and the log
encoding on every call, so `log.showSignature`, `color.ui` or `i18n.logOutputEncoding` in your Git configuration do
not change the result. `changelog check` and `changelog notes` read only files and need no Git.

## Platforms

| Platform | Status |
|:--|:--|
| Linux | Tested in CI, every push; also with the minimum SDK %min_dart% |
| macOS | Tested in CI, every push |
| Windows | Tested in CI, every push, except the integration tests against a real Trivy, which are skipped there. The API dump and the configuration use `/` in paths on every platform. |

CI also compiles the native executable with `dart compile exe` on all three platforms on every push.

<seealso>
    <category ref="start">
        <a href="Getting-Started.md">Getting started</a>
    </category>
    <category ref="security">
        <a href="Trivy-Installation.md">Installing Trivy</a>
    </category>
    <category ref="operations">
        <a href="Inspectra-On-Itself.md">Inspectra on itself</a>
    </category>
</seealso>
