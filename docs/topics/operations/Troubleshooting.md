# Troubleshooting

<primary-label ref="guide"/>

<show-structure for="chapter" depth="2"/>

<link-summary>The errors and surprises you are most likely to meet, and what to do about each.</link-summary>

<card-summary>Configuration errors, Trivy failures, stale builds, missing findings and coverage puzzles.</card-summary>

## Configuration

### Invalid Inspectra configuration at "…": unknown option {collapsible="true"}

A key is misspelled or at the wrong level. The message lists the valid keys at that position:

```text
Invalid Inspectra configuration at "inspectra.trivy.secrets": unknown option. Known options here: enabled, executable, filesystem, license, report_directory, secret, vulnerability.
```

Here `secrets` should be `secret`. See the [configuration reference](Configuration-Reference.md).

### expected true or false, got "yes" {collapsible="true"}

YAML 1.2 reads `yes`, `no`, `on` and `off` as strings. Write `true` and `false`.

### Undefined alias {collapsible="true"}

```text
Invalid Inspectra configuration at "pubspec.yaml": line 5, column 16: Undefined alias.
```

An unquoted glob starting with `*` is read as a YAML alias. Quote it: `'**.dart'`.

### My settings in pubspec.yaml are ignored {collapsible="true"}

An `%config_file%` exists in the package root. It takes precedence entirely; the two are not merged. Move everything
into one of them.

## build_runner

### Editing inspectra.yaml or trivy-secret.yaml does not rerun the builders {collapsible="true"}

They are not <tooltip term="build source">build sources</tooltip> by default. Move the configuration into
`pubspec.yaml`, or add the files to the sources - see [Build sources](Build-Sources.md). To rerun once:
`dart run build_runner clean` and build again.

### api.output changed from "…" to "…". Restart build_runner {collapsible="true"}

`build_runner` reads the output location when it starts. Stop `watch` or `serve` and start it again.

### --only-check fails with "I api/&lt;package&gt;.api" {collapsible="true"}

The committed dump is out of date. The warning above it shows the diff. Run `dart run build_runner build` and commit
the dump - after deciding the change is intended. See [Workflow](API-Workflow.md#fixing-a-failed-check).

### The secret scan of the builder misses a file the command line finds {collapsible="true"}

The builder only sees build sources. Root-level files such as `.env` or `analysis_options.yaml` are not sources by
default. Add them to the sources, or rely on the command line in CI.

## Trivy

### Could not start Trivy ("trivy"): No such file or directory {collapsible="true"}

Trivy is not installed or not on the `PATH` of the process running %product%. Install it, or set
`trivy.executable` or `%trivy_env%`. In IDEs started from a desktop launcher, the `PATH` may differ from your shell's.
See [Installing Trivy](Trivy-Installation.md#lookup).

### Trivy did not finish scanning …: it exited with 1 {collapsible="true"}

Trivy itself failed; its error output follows the message. Common causes:

| Trivy says | Cause | Fix |
|:--|:--|:--|
| `failed to download vulnerability DB` | No network, or the registry is blocked | Allow `mirror.gcr.io`, set `TRIVY_DB_REPOSITORY` to a mirror, or use an offline database |
| `unknown flag` | A very old Trivy | Update Trivy |
| `secret config file … error` | Invalid `%secret_config%` | Fix the YAML or the regular expression |
| `cache may be in use by another process` | Two Trivy processes share a cache | Run scans one after another, or give them separate `TRIVY_CACHE_DIR`s |

### The first vulnerability scan is slow {collapsible="true"}

It downloads the Trivy database, about 120 MB. Later scans reuse it. In CI, cache it - see
[CI integration](CI-Integration.md#the-trivy-database-cache).

## Findings

### A secret in test/ or example/ is not reported {collapsible="true"}

Trivy's built-in allow rules suppress findings in test and example directories and in Markdown files. Disable them in
`%secret_config%` - see [Secret rules](Trivy-Secret-Rules.md#trivy-s-built-in-allow-rules).

### The license scan reports UNKNOWN for a well-known package {collapsible="true"}

`unclassified`: the package's license file has text Trivy cannot match, for example a license with an added clause.
Read it; if acceptable, add the package to `ignored_packages`.
`no-license-file`: the package ships none, or it is not in the pub cache - run `dart pub get`.

### The license scan finds nothing at all {collapsible="true"}

By default it reports only forbidden, restricted and unknown licenses, and most of pub.dev is BSD, MIT or Apache. Add
`LOW` to its `severity` to see every license.

### The vulnerability scan reports a dev dependency {collapsible="true"}

It includes `dev_dependencies` by default. Upgrade it, or set `include_dev_dependencies: false` if build-time tooling
is out of scope for you.

## Coverage

### "dart test --coverage=…" failed with exit code 1 {collapsible="true"}

A test failed; its output is above the message. Coverage is not measured for a failing suite - fix the test first.

### A file is listed as "not loaded by any test" {collapsible="true"}

No test imports it, directly or indirectly, so the VM reports nothing for it. Import it from a test, or mark it
`// coverage:ignore-file` if it is not meant to be tested.

### Coverage differs from what my IDE shows {collapsible="true"}

The IDE may count different files: %product% reports only `report_on` minus `exclude` and drops lines marked with
`coverage:ignore` comments. Point the IDE at `coverage/lcov.info` to see exactly what %product% measured.

### The coverage of generated files is counted {collapsible="true"}

Add their pattern to `coverage.exclude`. Remember that setting `exclude` replaces the defaults.

## Still stuck

Run the failing command with the scan or check isolated - `dart run %package% trivy secret`,
`dart run %package% api check` - and open an issue at [%issues%](%issues%) with the output and the
`%pubspec_key%:` configuration.

<seealso>
    <category ref="reference">
        <a href="CLI-Reference.md#exit-codes">Exit codes</a>
        <a href="Builder-Reference.md#logging">Builder logging</a>
    </category>
    <category ref="config">
        <a href="Configuration-Overview.md#validation">Validation</a>
    </category>
</seealso>
