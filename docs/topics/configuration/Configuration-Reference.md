# Configuration reference

<primary-label ref="config"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Every option of the Inspectra configuration, with its type, default and effect.</link-summary>

<card-summary>The complete list of options, section by section, with defaults.</card-summary>

Keys are shown as they appear under `%pubspec_key%:` in `pubspec.yaml`, or at the top level of `%config_file%`. Paths
and globs are relative to the package root and use `/` on every platform. Durations are written as `500ms`, `30s`,
`10m` or `1h`.

Every key except `ignore` can also be set with `--set <path>=<value>` or an `INSPECTRA_<PATH>` environment variable,
for example `--set trivy.version=latest` or `INSPECTRA_NETWORK_PROXY`. See
[Overriding options](Configuration-Overview.md#overrides).

## Complete example with defaults {collapsible="true" default-state="expanded"}

Every option with its default value. Nothing here needs to be written out; the block shows what an empty
configuration means.

```yaml
inspectra:
  # fail_on: high                  # unset: the command's own default
  min_severity: unknown

  ignore: []                       # entries: id, package, reason, expires

  network:
    offline: false
    timeout: 30s
    max_attempts: 3
    retry_base_delay: 1s
    concurrency: 8
    # proxy: http://proxy.corp:3128   # unset: HTTPS_PROXY / HTTP_PROXY / NO_PROXY
    # ca_certificates: certs/corp-ca.pem
    osv_url: https://api.osv.dev
    # pub_hosted_url: https://pub.dev # unset: PUB_HOSTED_URL, else https://pub.dev

  inspect:
    fail_score: 30
    max_archive_bytes: 67108864
    max_extracted_bytes: 268435456
    max_entries: 20000
    entropy_excludes: [.g.dart, .freezed.dart, .mocks.dart, .pb.dart, .gr.dart]
    exclude_directories: [test, integration_test, example, benchmark, doc, docs, tool, extension]
    trusted_hosts: []

  trust:
    fresh_package_days: 7
    young_package_days: 30
    fresh_release_hours: 24
    min_likes: 5
    min_downloads: 100
    min_points_ratio: 0.5

  typosquat:
    allow: []
    popular: []

  format:
    enabled: false
    run_on_build: false
    fail_on_findings: true
    include: ['**.dart']
    exclude: ['**/.dart_tool/**', '**/build/**', '**.g.dart', '**.freezed.dart', '**.mocks.dart']
    # page_width: 80               # unset: from analysis_options.yaml

  lint:
    enabled: false
    run_on_build: false
    fail_on: info                  # error, warning, info or none

  api:
    enabled: false
    output: api/<package>.api
    ignored_libraries: []
    non_public_annotations: [internal, visibleForTesting]

  trivy:
    enabled: false
    mode: auto                     # auto, required or disabled
    version: 0.75.0                # an exact version or latest
    use_installed: true
    download: true
    # executable: /opt/trivy/trivy # unset: installed, cached or downloaded
    # install_directory: .tools/trivy   # unset: <user cache>/inspectra/trivy
    download_base_url: https://github.com/aquasecurity/trivy/releases/download
    latest_release_url: https://github.com/aquasecurity/trivy/releases/latest
    report_directory: .dart_tool/inspectra/trivy
    skip_db_update: false
    # db_repository: registry.corp/aquasecurity/trivy-db
    # cache_directory: .cache/trivy
    timeout: 10m
    connectivity_timeout: 3s
    extra_args: []

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

## fail_on and min_severity {id="severity-thresholds"}

Thresholds of the supply-chain commands and of the Trivy filesystem scan of `scan` and `trivy`. Severities are
`critical`, `high`, `medium`, `low` and `unknown`, case-insensitive.

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `fail_on` | severity | unset | The minimum severity that makes a command exit with `1`. Unset: the command's own default - any finding for `scan`, `audit` and `trivy`, `high` for `typosquat`, `critical` for `trust`. `inspect` and `add` decide by `inspect.fail_score` instead. `--fail-on` overrides it. |
| `min_severity` | severity | `unknown` | Findings below this severity are not reported at all. `--min-severity` overrides it. |

## ignore {id="ignore"}

Documented suppressions of findings of the supply-chain commands and of the Trivy filesystem scan of `scan` and
`trivy`. The configured Trivy scans have their own `ignored_*` lists.

```yaml
inspectra:
  ignore:
    - id: GHSA-xxxx-yyyy-zzzz          # rule id, advisory id or alias (CVE)
      package: http                    # optional: only for this package
      reason: Not reachable, we never parse untrusted multipart bodies.
      expires: 2027-01-31              # optional: revisit after this day
```

| Key | Type | Required | Description |
|:--|:--|:--|:--|
| `id` | string | yes | The rule id, advisory id or alias to suppress, such as `GHSA-…`, `CVE-…` or `HARDCODED_URL`. |
| `reason` | string | yes | Why the finding is acceptable. An entry without it is an error, so every suppression is auditable. |
| `package` | string | no | Restricts the entry to findings of this package. |
| `expires` | date, `YYYY-MM-DD` | no | The last day on which the entry applies. Afterwards it stops matching and every run warns about it. |

`ignore` can only be written in the file. `--ignore <ID>` suppresses an id for one run, without a reason.

## network {id="network"}

Settings for every connection %product% opens: OSV.dev, the pub repository and Trivy downloads.

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `offline` | boolean | `false` | Never open a connection. Commands that need the network exit with `69`; optional steps such as downloading Trivy are skipped. `--offline` sets it. |
| `timeout` | duration | `30s` | The timeout for connecting and for each response. |
| `max_attempts` | whole number, 1 to 100 | `3` | How often a request is attempted before giving up. |
| `retry_base_delay` | duration | `1s` | The first back-off delay; it doubles with every retry. |
| `concurrency` | whole number, 1 to 256 | `8` | The maximum number of concurrent requests to one service. |
| `proxy` | string | unset | An explicit proxy such as `http://proxy.corp:3128`. Unset: `HTTPS_PROXY`, `HTTP_PROXY` and `NO_PROXY` apply. |
| `ca_certificates` | string | unset | A PEM file with additional trusted certificate authorities, for proxies that intercept TLS. |
| `osv_url` | string | `https://api.osv.dev` | An OSV.dev compatible API, for example an internal mirror. |
| `pub_hosted_url` | string | `PUB_HOSTED_URL`, else `https://pub.dev` | The pub repository. |

## inspect {id="inspect"}

The source inspection of `inspect` and `add`.

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `fail_score` | whole number, 1 to 100 | `30` | The risk score from which `inspect` exits with `1` and `add` refuses to install. |
| `max_archive_bytes` | whole number | `67108864` (64 MiB) | The largest package archive that is downloaded. |
| `max_extracted_bytes` | whole number | `268435456` (256 MiB) | The largest total size of all archive entries, which stops decompression bombs. |
| `max_entries` | whole number | `20000` | The largest number of archive entries. |
| `entropy_excludes` | list of strings | `[.g.dart, .freezed.dart, .mocks.dart, .pb.dart, .gr.dart]` | File name suffixes of generated code that the entropy scanner skips. |
| `exclude_directories` | list of strings | `[test, integration_test, example, benchmark, doc, docs, tool, extension]` | Top level directories skipped by the code pattern and entropy scanners. Unicode and archive checks still cover every file. |
| `trusted_hosts` | list of strings | `[]` | Host names the hard-coded URL rule never reports, on top of the built-in Dart, Flutter and GitHub hosts. |

## trust {id="trust"}

Thresholds of the pub.dev trust assessment of `trust`, `inspect` and `add`.

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `fresh_package_days` | whole number | `7` | A package first published less than this many days ago is `CRITICAL`. |
| `young_package_days` | whole number | `30` | A package first published less than this many days ago is `MEDIUM`. |
| `fresh_release_hours` | whole number | `24` | A version published less than this many hours ago is `CRITICAL`. |
| `min_likes` | whole number | `5` | Fewer likes are reported as low endorsement. |
| `min_downloads` | whole number | `100` | Fewer downloads in 30 days are reported as low usage. |
| `min_points_ratio` | number, 0 to 1 | `0.5` | A lower ratio of pub points is reported as low quality. |

## typosquat {id="typosquat"}

The typosquatting detector of `typosquat`, `scan`, `add` and the pre-commit hook.

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `allow` | list of strings | `[]` | Package names that are never reported, for example internal packages that resemble popular ones. |
| `popular` | list of strings | `[]` | Additional names to protect, for example your most used internal packages. |

## format {id="format"}

The format check. See [Format check](Format-Check.md).

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `false` | Whether `check` runs the format check. `dart run %package% format` runs it regardless. |
| `run_on_build` | boolean | `false` | Whether the `inspectra:format` builder checks on `build_runner build`. |
| `fail_on_findings` | boolean | `true` | Whether an unformatted file fails the build or the command. |
| `include` | list of globs | `['**.dart']` | The files that are checked. |
| `exclude` | list of globs | `['**/.dart_tool/**', '**/build/**', '**.g.dart', '**.freezed.dart', '**.mocks.dart']` | Files never checked. Replaces the default when set. |
| `page_width` | whole number, 1 to 1000 | unset | The line length passed to `dart format`. Unset: `formatter: page_width` of `analysis_options.yaml`, else 80. |

## lint {id="lint"}

The lint check. See [Lint check](Lint-Check.md).

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `false` | Whether `check` runs the lint check. `dart run %package% lint` runs it regardless. |
| `run_on_build` | boolean | `false` | Whether the `inspectra:lint` builder analyzes on `build_runner build`. |
| `fail_on` | `error`, `warning`, `info` or `none` | `info` | The lowest <tooltip term="diagnostic">diagnostic</tooltip> severity that fails the check. |

The rules themselves live in `analysis_options.yaml`; see [Lint preset](Lint-Preset.md).

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

The configured scans, and how Trivy is provisioned for every command that runs it. See
[Security and compliance](Trivy-Overview.md) and [Installing Trivy](Trivy-Installation.md).

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `false` | Whether the configured scans run in `check`, `trivy` and the builders. The scans' own `enabled` switches apply on top of it. `scan` runs Trivy regardless. |
| `mode` | `auto`, `required` or `disabled` | `auto` | `auto`: an unavailable Trivy is skipped with a warning. `required`: it is an error, exit code `69`. `disabled`: Trivy is never located, downloaded or run. |
| `version` | string | `0.75.0` | The Trivy version to download, or `latest`. The default is pinned per %product% release. |
| `use_installed` | boolean | `true` | Use an installed Trivy whatever its version. `false` accepts only exactly `version`. |
| `download` | boolean | `true` | Allow downloading Trivy when it is not installed; only when online. |
| `executable` | string | unset | The Trivy executable: a name on the `PATH` or a path relative to the package root. Disables every other lookup. The environment variable `%trivy_env%` overrides it. |
| `install_directory` | string | `<user cache>/inspectra/trivy` | Where downloaded Trivy binaries are stored, one directory per version. |
| `download_base_url` | string | `https://github.com/aquasecurity/trivy/releases/download` | The release assets, or a mirror providing them under `<base>/v<version>/`. |
| `latest_release_url` | string | `https://github.com/aquasecurity/trivy/releases/latest` | The redirect that resolves `version: latest`. |
| `report_directory` | string | `%report_dir%` | Where the command line writes the JSON report of each scan. The builders write theirs to the artifact tree instead. |
| `skip_db_update` | boolean | `false` | Pass `--skip-db-update`, for a pre-seeded `cache_directory`. |
| `db_repository` | string | unset | Pass `--db-repository`, an OCI mirror of the Trivy database. |
| `cache_directory` | string | unset | Pass `--cache-dir`. |
| `timeout` | duration | `10m` | The maximum run time of one Trivy scan. |
| `connectivity_timeout` | duration | `3s` | How long the download host may take to answer before Trivy is not downloaded. |
| `extra_args` | list of strings | `[]` | Arguments appended verbatim to the Trivy command line. |
| `secret` | mapping | | [Secret scan](#trivy-secret) |
| `license` | mapping | | [License scan](#trivy-license) |
| `vulnerability` | mapping | | [Vulnerability scan](#trivy-vulnerability) |
| `filesystem` | mapping | | [Filesystem scan](#trivy-filesystem) |

`skip_db_update`, `db_repository`, `cache_directory`, `timeout` and `extra_args` apply to the Trivy filesystem scan of
`scan` and of `trivy` without configured scans.
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

There is no `run_on_build`: the filesystem scan has no builder. `scanners`, `severity` and `skip_dirs` also configure the
Trivy part of `scan`, and of `trivy` without configured scans. Details: [Filesystem scan](Trivy-Filesystem-Scan.md).

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
