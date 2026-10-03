# Configuration reference

<primary-label ref="config"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Every option of the Inspectra configuration, with its type, default and effect.</link-summary>

<card-summary>The complete list of options, section by section, with defaults.</card-summary>

Keys are shown as they appear under `%pubspec_key%:` in `pubspec.yaml`, or at the top level of `%config_file%`. Paths
and globs are relative to the package root and use `/` on every platform.

## Complete example with defaults {collapsible="true" default-state="expanded"}

Every option with its default value. Nothing here needs to be written out; the block shows what an empty
configuration means.

```yaml
inspectra:
  api:
    enabled: false
    output: api/<package>.api
    ignored_libraries: []
    non_public_annotations: [internal, visibleForTesting]

  trivy:
    enabled: false
    # executable: trivy            # unset: "trivy" from the PATH
    report_directory: .dart_tool/inspectra/trivy

    secret:
      enabled: true
      run_on_build: true
      fail_on_findings: true
      severity: [CRITICAL, HIGH, MEDIUM, LOW]
      # config: trivy-secret.yaml  # unset: trivy-secret.yaml when it exists
      include: ['**.dart', '**.yaml', '**.yml', '**.json', '**.env', '**.properties']
      exclude: ['**/.dart_tool/**', '**/build/**', '**/.git/**']

    license:
      enabled: true
      run_on_build: false
      fail_on_findings: true
      severity: [CRITICAL, HIGH, UNKNOWN]
      ignored_licenses: []
      ignored_packages: []
      include_dev_dependencies: false

    vulnerability:
      enabled: true
      run_on_build: false
      fail_on_findings: true
      severity: [CRITICAL, HIGH, MEDIUM, LOW]
      include_dev_dependencies: true
      ignore_unfixed: false
      ignored_vulnerabilities: []

    filesystem:
      enabled: false
      fail_on_findings: true
      severity: [CRITICAL, HIGH, MEDIUM, LOW]
      scanners: [vuln, secret, misconfig]
      skip_dirs: [.dart_tool, build, .git]

  coverage:
    enabled: false
    runner: dart
    output_directory: coverage
    report_on: [lib]
    exclude: ['**.g.dart', '**.freezed.dart', '**.mocks.dart']
    # min_line_coverage: 80        # unset: report only, never fail
    test_arguments: []
```

## api {id="api"}

Public API validation. See [Public API validation](API-Overview.md).

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `false` | Whether the API builder writes the dump and `api check` / `check` verify it. |
| `output` | string | `api/<package>.api` | The dump file. `<package>` is the `name` from `pubspec.yaml`. Changing it requires restarting `build_runner`, which reads it when the build starts. |
| `ignored_libraries` | list of globs | `[]` | Public libraries left out of the dump, for example `[lib/testing.dart]`. Matched against the path relative to the package root. |
| `non_public_annotations` | list of strings | `[internal, visibleForTesting]` | Annotations that keep a declaration out of the dump. Either the name of a constant (`internal`) or of the annotation class (`Internal`). |

Details: [API configuration](API-Configuration.md).

## trivy {id="trivy"}

Settings shared by all scans. See [Security and compliance](Trivy-Overview.md).

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `false` | Whether any scan runs. The scans' own `enabled` switches apply on top of it. |
| `executable` | string | unset | The Trivy executable: a name on the `PATH` or a path. Unset means `trivy`. The environment variable `%trivy_env%` overrides it. |
| `report_directory` | string | `%report_dir%` | Where the command line writes the JSON report of each scan. The builders write theirs to the artifact tree instead. |
| `secret` | mapping | | [Secret scan](#trivy-secret) |
| `license` | mapping | | [License scan](#trivy-license) |
| `vulnerability` | mapping | | [Vulnerability scan](#trivy-vulnerability) |
| `filesystem` | mapping | | [Filesystem scan](#trivy-filesystem) |

### Shared scan options {id="scan-options"}

Each scan has these options; the defaults differ per scan and are listed in its table.

| Key | Type | Description |
|:--|:--|:--|
| `enabled` | boolean | Whether this scan runs when `trivy.enabled` is `true`. Naming a scan on the command line runs it regardless. |
| `run_on_build` | boolean | Whether the scan's builder runs it on `dart run build_runner build`. Not available for the filesystem scan. |
| `fail_on_findings` | boolean | Whether findings fail the build or the command. When `false`, findings are logged as a warning and listed as *(not failing)*. |
| `severity` | list of severities | The severities that are reported; findings of any other severity are dropped. One or more of `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`, `UNKNOWN`, case-insensitive; an empty list is an error. |

### trivy.secret {id="trivy-secret"}

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `true` | |
| `run_on_build` | boolean | `true` | |
| `fail_on_findings` | boolean | `true` | |
| `severity` | list | `[CRITICAL, HIGH, MEDIUM, LOW]` | |
| `config` | string | unset | The Trivy secret configuration. Unset: `%secret_config%` when it exists, otherwise Trivy's built-in rules only. A file named here must exist. |
| `include` | list of globs | `['**.dart', '**.yaml', '**.yml', '**.json', '**.env', '**.properties']` | The files that are scanned. Replaces the default when set. |
| `exclude` | list of globs | `['**/.dart_tool/**', '**/build/**', '**/.git/**']` | The files that are never scanned, even when included. Replaces the default when set. |

Details: [Secret scan](Trivy-Secret-Scan.md), [Secret rules](Trivy-Secret-Rules.md).

### trivy.license {id="trivy-license"}

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `true` | |
| `run_on_build` | boolean | `false` | |
| `fail_on_findings` | boolean | `true` | |
| `severity` | list | `[CRITICAL, HIGH, UNKNOWN]` | Forbidden, restricted and unclassifiable licenses. See [License severities](Trivy-Severities.md#licenses). |
| `ignored_licenses` | list of strings | `[]` | <tooltip term="SPDX identifier">SPDX identifiers</tooltip> that are never reported, case-insensitive. |
| `ignored_packages` | list of strings | `[]` | Package names whose license is never checked. |
| `include_dev_dependencies` | boolean | `false` | Whether packages reachable only through `dev_dependencies` are checked. |

Details: [License scan](Trivy-License-Scan.md).

### trivy.vulnerability {id="trivy-vulnerability"}

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `true` | |
| `run_on_build` | boolean | `false` | |
| `fail_on_findings` | boolean | `true` | |
| `severity` | list | `[CRITICAL, HIGH, MEDIUM, LOW]` | |
| `include_dev_dependencies` | boolean | `true` | Whether packages reachable only through `dev_dependencies` are checked. When `false`, `pubspec.lock` is narrowed to shipped dependencies first. |
| `ignore_unfixed` | boolean | `false` | Whether vulnerabilities without a released fix are left out (Trivy's `--ignore-unfixed`). |
| `ignored_vulnerabilities` | list of strings | `[]` | <tooltip term="CVE">CVE</tooltip> or <tooltip term="GHSA">GHSA</tooltip> identifiers that are never reported, case-insensitive. A vulnerability is ignored when any of its identifiers is listed. |

Details: [Vulnerability scan](Trivy-Vulnerability-Scan.md).

### trivy.filesystem {id="trivy-filesystem"}

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `false` | Off by default even with `trivy.enabled`, because it overlaps with the other scans. |
| `fail_on_findings` | boolean | `true` | |
| `severity` | list | `[CRITICAL, HIGH, MEDIUM, LOW]` | |
| `scanners` | list | `[vuln, secret, misconfig]` | The Trivy scanners to run: one or more of `vuln`, `secret`, `misconfig`, `license`. |
| `skip_dirs` | list of strings | `[.dart_tool, build, .git]` | Directories Trivy skips, passed as `--skip-dirs`. Replaces the default when set. |

There is no `run_on_build`: the filesystem scan has no builder. Details: [Filesystem scan](Trivy-Filesystem-Scan.md).

## coverage {id="coverage"}

The coverage gate. See [Coverage](Coverage-Overview.md).

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `false` | Whether `check` runs the gate. `dart run %package% coverage` runs it regardless. |
| `runner` | `dart` or `flutter` | `dart` | Which test runner collects the coverage. |
| `output_directory` | string | `coverage` | Where `lcov.info` and the raw hit maps are written. |
| `report_on` | list of directories | `[lib]` | The directories whose files are reported. |
| `exclude` | list of globs | `['**.g.dart', '**.freezed.dart', '**.mocks.dart']` | Files left out of the report. Replaces the default when set. |
| `min_line_coverage` | number, 0 to 100 | unset | The line coverage in percent below which the gate fails. Unset: report only. `--min` overrides it. |
| `test_arguments` | list of strings | `[]` | Extra arguments for the test runner, such as `[--exclude-tags, slow]`. |

Details: [Coverage configuration](Coverage-Configuration.md).

## Lists replace, they do not merge

Every list option replaces its default when you set it. To add a glob to the secret scan, repeat the defaults:

```yaml
inspectra:
  trivy:
    secret:
      include: ['**.dart', '**.yaml', '**.yml', '**.json', '**.env', '**.properties', '**.toml']
```

<seealso>
    <category ref="config">
        <a href="Configuration-Overview.md">Where the configuration lives</a>
        <a href="Build-Sources.md">Build sources</a>
    </category>
    <category ref="security">
        <a href="Trivy-Configuration-Reference.md">Trivy configuration reference</a>
    </category>
    <category ref="reference">
        <a href="Library-API.md">Library API</a>
    </category>
</seealso>
