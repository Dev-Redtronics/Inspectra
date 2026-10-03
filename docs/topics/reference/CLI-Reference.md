# Command line reference

<primary-label ref="cli"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Every command and option of dart run inspectra, with output and exit codes.</link-summary>

<card-summary>check, api dump, api check, trivy and coverage; global options and exit codes.</card-summary>

```text
Usage: inspectra <command> [arguments]

Global options:
-h, --help                Print this usage information.
-C, --directory=<path>    The package to inspect.
                          (defaults to ".")

Available commands:
  api        Records or checks the public API dump.
  check      Runs every enabled check: format, lint, API, Trivy scans and coverage.
  coverage   Runs the tests with coverage, writes lcov.info and checks the threshold.
  format     Checks that the Dart files are formatted, or formats them with --fix.
  lint       Analyzes the package with the rules of analysis_options.yaml.
  trivy      Runs Trivy scans: every enabled one, or the ones named.
```

Run it from a package that depends on %product%:

```bash
dart run inspectra <command>
```

## Global options

| Option | Default | Description |
|:--|:--|:--|
| `-C`, `--directory <path>` | `.` | The package to inspect: the directory containing its `pubspec.yaml`. The configuration is read from there, Trivy runs there, and reports are written there. |
| `-h`, `--help` | | Usage of the command line or of a command. |

```bash
dart run inspectra -C packages/core check
```

## check {id="check"}

```bash
dart run inspectra check
```

Runs every enabled check in this order and fails if any of them fails:

1. The [format check](#format), when `format.enabled`.
2. The [lint check](#lint), when `lint.enabled`.
3. The [API check](#api-check), when `api.enabled`.
4. Every [enabled Trivy scan](#trivy), when `trivy.enabled`.
5. The [coverage gate](#coverage), when `coverage.enabled`.

All checks run even when an earlier one fails, so one run reports everything. With nothing enabled it prints
`Nothing is enabled. Enable "format", "lint", "api", "trivy" or "coverage" in the Inspectra configuration.` and exits
with `0`.

## format {id="format"}

```bash
dart run inspectra format          # check
dart run inspectra format --fix    # format in place
```

Checks the files selected by `format.include` and `format.exclude` with `dart format`, or formats them with `--fix`.
Runs whether or not `format.enabled` is set, and writes `.dart_tool/inspectra/format.json`.

| Option | Description |
|:--|:--|
| `--fix` | Format the files instead of checking them. Lists the files it changed and never fails on formatting. |

| Result | Exit code |
|:--|:--|
| Everything formatted, or `--fix` | `0` |
| Unformatted files, with `fail_on_findings: true` | `1` |
| A file that does not parse | `2` |

## lint {id="lint"}

```bash
dart run inspectra lint            # analyze
dart run inspectra lint --fix      # dart fix --apply, then analyze
```

Runs `dart analyze` in the package root and fails when a diagnostic at or above `lint.fail_on` is found. Runs whether
or not `lint.enabled` is set, and writes `.dart_tool/inspectra/lint.json`.

| Option | Description |
|:--|:--|
| `--fix` | Run `dart fix --apply` before analyzing. |

## api dump {id="api-dump"}

```bash
dart run inspectra api dump
```

Renders the public API and writes it to `api.output`. Prints `Wrote the public API to <path>.` Works whether or not
`api.enabled` is set.

## api check {id="api-check"}

```bash
dart run inspectra api check
```

Renders the public API and compares it with the dump at `api.output`.

| Result | Output | Exit code |
|:--|:--|:--|
| Equal | `The public API matches api/<package>.api.` | `0` |
| Different | `The public API changed.`, the diff, and how to record it | `1` |
| No dump | `No public API dump has been recorded yet at …` | `1` |

## trivy {id="trivy"}

```bash
dart run inspectra trivy                         # every enabled scan
dart run inspectra trivy secret                  # one scan
dart run inspectra trivy license vulnerability   # several scans
```

| Arguments | Runs |
|:--|:--|
| none | Every scan whose `enabled` is `true`, if `trivy.enabled` is `true`; otherwise prints `Trivy is disabled. …` and exits with `0` |
| scan names | Exactly the named scans, in the order secret, license, vulnerability, filesystem - regardless of `enabled` |

Scan names: `secret`, `license`, `vulnerability`, `filesystem`. An unknown name is a usage error.

Each scan prints its summary and writes `%report_dir%/<scan>.json`. See [Reports](Trivy-Reports.md).

## coverage {id="coverage"}

```bash
dart run inspectra coverage
dart run inspectra coverage --min 85
```

Runs the tests with coverage, writes `lcov.info`, prints the table and checks the threshold. Runs whether or not
`coverage.enabled` is set.

| Option | Description |
|:--|:--|
| `--min <percent>` | The threshold for this run, overriding `coverage.min_line_coverage`. A number from 0 to 100. |

## Exit codes {id="exit-codes"}

<include from="lib.topic" element-id="exit-codes"/>

Exit code `2` always comes with a message on standard error naming the cause:

```text
Invalid Inspectra configuration at "inspectra.trivy.secrets": unknown option. Known options here: …
Could not start Trivy ("trivy"): No such file or directory
"dart format" failed with exit code 65.
"dart analyze" failed with exit code 64.
Trivy did not finish scanning /tmp/…: it exited with 1. This is a failure of Trivy itself, not a finding.
"dart test --coverage=…" failed with exit code 1; see its output above.
FileSystemException: No pubspec.lock found; run "dart pub get" first., path = '…'
```

## Output streams

Results go to standard output; errors that prevent a check from running go to standard error. The test runner's own
output during `coverage` is passed through as it is produced.

<seealso>
    <category ref="reference">
        <a href="Builder-Reference.md">Builder reference</a>
        <a href="Library-API.md">Library API</a>
    </category>
    <category ref="operations">
        <a href="CI-Integration.md">CI integration</a>
        <a href="Troubleshooting.md">Troubleshooting</a>
    </category>
</seealso>
