# Compatibility

<primary-label ref="guide"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Supported Dart, build_runner, Trivy and platform versions, and what CI verifies.</link-summary>

<card-summary>The versions Inspectra requires, the versions it is tested with, and the platforms CI covers.</card-summary>

| Component | Required | Tested in CI |
|:--|:--|:--|
| Dart SDK | %min_dart% | Stable channel; locally %tested_dart% |
| `build_runner` | %min_build_runner%, for `--only-check` | %min_build_runner% |
| Trivy | A release with `--scanners` | %tested_trivy% |
| Flutter | Any release bundling Dart %min_dart%+ | Not in CI |

## Dart SDK

%product% requires Dart %min_dart% or later, as stated in its `pubspec.yaml`. It uses the analyzer's current element
model, which needs a recent SDK.

## Dependencies

| Package | Version | Used for |
|:--|:--|:--|
| `analyzer` | ^%analyzer_version% | Resolving libraries for the API dump |
| `build` | ^%build_version% | The builders |
| `coverage` | ^%coverage_version% | Merging hit maps, ignore comments, lcov |
| `args` | ^2.7.0 | The command line |
| `glob` | ^2.2.0 | `include`, `exclude`, `ignored_libraries` |
| `path` | ^1.9.1 | Paths on every platform |
| `yaml` | ^3.1.4 | Reading the configuration |

`args`, `glob`, `path` and `yaml` are dependencies of `analyzer`, `build` or `coverage` anyway, so %product% adds no
package to your resolution beyond those three.

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
%tested_trivy%, the version pinned in its CI. Dart support - pub lock files and the GitHub advisories for pub - has been
in Trivy for many releases.

## Platforms

| Platform | Status |
|:--|:--|
| Linux | Tested in CI, every push |
| macOS | Tested in CI, every push |
| Windows | Expected to work; not covered by CI. The API dump and the configuration use `/` in paths on every platform. |

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
