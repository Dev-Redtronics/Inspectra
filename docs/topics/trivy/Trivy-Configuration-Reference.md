# Trivy configuration reference

<primary-label ref="config"/>
<secondary-label ref="requires-trivy"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Every option of the trivy section, and every file and variable that influences the scans.</link-summary>

<card-summary>All Trivy options in one place, including Trivy's own files and environment variables.</card-summary>

This page collects everything that influences a scan: the `trivy` section of the %product% configuration, the files
Trivy reads from the package root, and the environment.

## The trivy section

```yaml
inspectra:
  trivy:
    enabled: false
    mode: auto
    version: 0.75.0
    use_installed: true
    download: true
    # executable: /opt/trivy/trivy
    # install_directory: .tools/trivy
    download_base_url: https://github.com/aquasecurity/trivy/releases/download
    latest_release_url: https://github.com/aquasecurity/trivy/releases/latest
    report_directory: .dart_tool/inspectra/trivy
    skip_db_update: false
    # db_repository: registry.corp/aquasecurity/trivy-db
    # cache_directory: .cache/trivy
    timeout: 10m
    connectivity_timeout: 3s
    extra_args: []
    secret: { ... }
    license: { ... }
    vulnerability: { ... }
    filesystem: { ... }
```

### Scans

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `false` | Master switch for the configured scans of `check`, `trivy` and the builders. `scan` runs Trivy regardless. |
| `report_directory` | string | `%report_dir%` | Where the command line writes `<scan>.json`. |

### Provisioning {id="provisioning"}

How the command line finds or downloads Trivy; see [Installing Trivy](Trivy-Installation.md#provisioning).

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `mode` | `auto`, `required`, `disabled` | `auto` | `auto` skips an unavailable Trivy with a warning where it can, `required` makes it an error (exit code `69`), `disabled` never locates, downloads or runs Trivy. |
| `version` | string | `0.75.0` | The version to download, or `latest`. |
| `use_installed` | boolean | `true` | Use an installed Trivy whatever its version. `false` enforces exactly `version`. |
| `download` | boolean | `true` | Allow downloading Trivy when it is not installed, only when the network is available. |
| `executable` | string | unset | Use exactly this executable, a name on the `PATH` or a path relative to the package root; disables every other lookup. `%trivy_env%` overrides it. |
| `install_directory` | string | `<user cache>/inspectra/trivy` | Where downloads are stored, one directory per version. |
| `download_base_url` | string | GitHub releases | The release assets, or a mirror providing `trivy_<version>_<platform>.tar.gz` / `.zip` and `trivy_<version>_checksums.txt` under `<base>/v<version>/`. |
| `latest_release_url` | string | GitHub latest release | The redirect that resolves `version: latest`. |
| `connectivity_timeout` | duration | `3s` | How long the download host may take to answer before Trivy is not downloaded. |

The checksum verification of a download cannot be disabled.

### Trivy run of scan {id="scan-run"}

These apply to the Trivy filesystem scan of `scan`, and of `trivy` without configured scans.

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `skip_db_update` | boolean | `false` | Pass `--skip-db-update`, for a pre-seeded cache. |
| `db_repository` | string | unset | Pass `--db-repository`, a mirror of the Trivy database. |
| `cache_directory` | string | unset | Pass `--cache-dir`. |
| `timeout` | duration | `10m` | The maximum run time of the scan, passed as `--timeout`. |
| `extra_args` | list of strings | `[]` | Arguments appended verbatim to the Trivy command line. |

`trivy.filesystem.scanners`, `severity` and `skip_dirs` select what it scans.

Every key can also be set with `--set trivy.<key>=<value>` or `INSPECTRA_TRIVY_<KEY>`; `scan` and `trivy` have
dedicated flags for the provisioning keys. See [Overriding options](Configuration-Overview.md#overrides).

## Per scan

| Key | Secret | License | Vulnerability | Filesystem |
|:--|:--|:--|:--|:--|
| `enabled` | `true` | `true` | `true` | `false` |
| `run_on_build` | `true` | `false` | `false` | - |
| `fail_on_findings` | `true` | `true` | `true` | `true` |
| `severity` | `C, H, M, L` | `C, H, U` | `C, H, M, L` | `C, H, M, L` |
| `config` | unset | - | - | - |
| `include` | 6 globs | - | - | - |
| `exclude` | 3 globs | - | - | - |
| `ignored_licenses` | - | `[]` | - | - |
| `ignored_packages` | - | `[]` | - | - |
| `include_dev_dependencies` | - | `false` | `true` | - |
| `ignore_unfixed` | - | - | `false` | - |
| `ignored_vulnerabilities` | - | - | `[]` | - |
| `scanners` | - | - | - | `vuln, secret, misconfig` |
| `skip_dirs` | - | - | - | `.dart_tool, build, .git` |

`C, H, M, L, U` stand for `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`, `UNKNOWN`. Each option is described on its scan's page:
[secret](Trivy-Secret-Scan.md), [license](Trivy-License-Scan.md), [vulnerability](Trivy-Vulnerability-Scan.md),
[filesystem](Trivy-Filesystem-Scan.md).

## Files Trivy reads from the package root

Trivy runs in the package root, so these files apply to every scan:

| File | Read by | Purpose |
|:--|:--|:--|
| `trivy-secret.yaml` | Secret scan, filesystem scan | Secret rules; passed explicitly with `--secret-config`. See [Secret rules](Trivy-Secret-Rules.md). |
| `trivy.yaml` | Trivy itself | Trivy's own configuration, such as `license.forbidden`, `cache.dir` or `db.repository`. Flags %product% passes take precedence. |
| `.trivyignore` | Trivy itself | IDs to ignore: vulnerabilities, secret rules, licenses, misconfiguration checks. |

## Environment variables

| Variable | Read by | Effect |
|:--|:--|:--|
| `%trivy_env%` | %product% | The Trivy executable; overrides `trivy.executable`. |
| `INSPECTRA_TRIVY_<KEY>` | %product% | Any key of the `trivy` section, such as `INSPECTRA_TRIVY_VERSION=latest` or `INSPECTRA_TRIVY_MODE=required`. |
| `INSPECTRA_CACHE_DIR` | %product% | Replaces `<user cache>/inspectra`, and with it the default install directory. |
| `TRIVY_CACHE_DIR` | Trivy | Cache and database directory. |
| `TRIVY_DB_REPOSITORY` | Trivy | Registry of the vulnerability database. |
| `TRIVY_SKIP_DB_UPDATE` | Trivy | Use the cached database as it is. |
| `TRIVY_OFFLINE_SCAN` | Trivy | Avoid network requests while scanning. |
| `TRIVY_SKIP_VERSION_CHECK` | Trivy | Do not check for a newer Trivy. |

## Flags Inspectra passes

For reference, the flags of each Trivy invocation. They cannot be changed through `trivy.yaml`, because flags take
precedence over it.

| Scan | Flags |
|:--|:--|
| all | `fs --quiet --format json --output <temp file> --severity <severity>` |
| Secret | `--scanners secret [--secret-config <file>]` |
| License | `--scanners license --license-full`, with all five severities; %product% filters afterwards |
| Vulnerability | `--scanners vuln [--ignore-unfixed]` |
| Filesystem | `--scanners <scanners> --skip-dirs <dir>... [--secret-config <file>] [--license-full]` |

The filesystem scan of `scan`, and of `trivy` without configured scans, runs
`fs --format json --quiet --exit-code 0 --scanners <scanners> --severity <severity> --skip-dirs <dir>... --timeout <timeout> [--skip-db-update] [--db-repository <repo>] [--cache-dir <dir>] <extra_args> <package root>`.

<seealso>
    <category ref="security">
        <a href="Trivy-Overview.md">Security and compliance</a>
        <a href="Trivy-Installation.md">Installing Trivy</a>
    </category>
    <category ref="config">
        <a href="Configuration-Reference.md">Configuration reference</a>
    </category>
    <category ref="external">
        <a href="%trivy_docs%/configuration/">Trivy configuration</a>
        <a href="%trivy_docs%/configuration/filtering/">Trivy filtering and .trivyignore</a>
    </category>
</seealso>
