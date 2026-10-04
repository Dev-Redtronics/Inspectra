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
    executable: trivy
    report_directory: .dart_tool/inspectra/trivy
    secret: { ... }
    license: { ... }
    vulnerability: { ... }
    filesystem: { ... }
```

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `false` | Master switch for every scan. |
| `executable` | string | `trivy` | The Trivy executable, a name on the `PATH` or a path relative to the package root. |
| `report_directory` | string | `%report_dir%` | Where the command line writes `<scan>.json`. |

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
