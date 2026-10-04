# Command line reference

<primary-label ref="cli"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Every command and option of the inspectra command line, with output and exit codes.</link-summary>

<card-summary>scan, audit, inspect, trust, typosquat, add, hook, trivy, check, format, lint, style, api, coverage and changelog; options and exit codes.</card-summary>

```text
Supply-chain security scanner for Dart and Flutter projects.

Usage: inspectra <command> [arguments]

Global options:
-h, --help                Print this usage information.
    --version             Print the Inspectra version and exit.
-C, --directory=<path>    The package or project to work on.

Available commands:
  add         Audit a package and add its exact version to pubspec.yaml.
  api         Record or check the public API dump.
  audit       Scan pubspec.lock against the OSV.dev vulnerability database.
  changelog   Generate the changelog from Conventional Commits, check it and print release notes.
  check       Run every enabled package check: format, lint, style, API, changelog, Trivy scans and coverage.
  coverage    Run the tests with coverage, write lcov.info and check the threshold.
  format      Check that the Dart files are formatted, or format them with --fix.
  hook        Install or remove the Git pre-commit hook.
  inspect     Statically analyse a pub.dev package before adding it.
  lint        Analyze the package with the rules of analysis_options.yaml.
  scan        Run every project check: OSV.dev audit, supply chain checks and Trivy (default).
  style       Check the Dart files against the built-in and custom style rules.
  trivy       Run Trivy: the configured scans, or a filesystem scan of the package.
  trust       Query pub.dev and print a trust assessment for a package.
  typosquat   Scan pubspec.yaml for typosquatting and dependency confusion risks.

Run "inspectra help <command>" for more information about a command.
```

Run it from a package that depends on %product%, or install it globally:

```bash
dart run inspectra <command>               # as a dev dependency
dart pub global activate inspectra         # or globally ...
inspectra <command>                        # ... and run it directly
```

Without a command, `inspectra` runs [`scan`](#scan): `inspectra`, `inspectra -f json` and `inspectra scan -f json`
are the same.

## Global options

Global options go before the command.

| Option | Description |
|:--|:--|
| `-C`, `--directory <path>` | The package or project to work on, relative to the current directory. The configuration is read from there, Trivy runs there, and reports are written there. Defaults to the current directory. |
| `--version` | Print `inspectra <version>` and exit with `0`. |
| `-h`, `--help` | Usage of the command line, or of a command with `inspectra <command> --help`. |

```bash
dart run inspectra -C packages/core check
inspectra --version
```

## Shared options {id="shared-options"}

The supply-chain commands - `scan`, `audit`, `inspect`, `trust`, `typosquat`, `add`, `hook` - and `trivy` share these
options:

| Option | Description |
|:--|:--|
| `--config <path>` | The configuration file. Default: `%config_file%` if present, else the `%pubspec_key%:` section of `pubspec.yaml`. See [Where the configuration lives](Configuration-Overview.md). |
| `--set <key=value>` | Override a configuration key by its dotted path, for example `--set trivy.version=latest`. Repeatable. An unknown key is a configuration error. |
| `-f`, `--format` | `text` (default), `json`, `sarif` or `markdown`. |
| `-o`, `--output <path>` | Write the report to a file instead of standard output. |
| `--[no-]color` | Force or disable ANSI colours. Default: detected from the terminal. |
| `-q`, `--quiet` | Only print warnings and errors. |
| `-v`, `--verbose` | Print diagnostics and list clean packages. |
| `--offline` | Never open a network connection: no HTTP request, no Trivy download, and Trivy runs with `--skip-db-update --offline-scan`. Same as `--set network.offline=true`. |
| `--fail-on <severity>` | Minimum severity that makes the command exit with `1`: `critical`, `high`, `medium`, `low` or `unknown`. Same as `fail_on`. |
| `--min-severity <severity>` | Hide findings below this severity. Same as `min_severity`. |
| `-i`, `--ignore <ID>` | Ignore a rule, advisory id or alias. Repeatable. For a documented, expiring suppression use the [`ignore`](Configuration-Reference.md#ignore) list. |
| `--exit-zero` | Exit with `0` even when findings reach the threshold. Never hides usage, input or availability errors. |

`scan` and `trivy` also take the Trivy provisioning options:

| Option | Configuration key | Description |
|:--|:--|:--|
| `--trivy-mode <mode>` | `trivy.mode` | `auto`, `required` or `disabled`. |
| `--trivy-version <version>` | `trivy.version` | The Trivy version to download, or `latest`. |
| `--[no-]trivy-download` | `trivy.download` | Allow downloading Trivy when it is not installed. |
| `--[no-]trivy-use-installed` | `trivy.use_installed` | Use an installed Trivy even if its version differs. |
| `--trivy-executable <path>` | `trivy.executable` | The Trivy executable to use; disables every other lookup. |

See [Installing Trivy](Trivy-Installation.md#provisioning) for how these combine.

Progress and errors go to standard error, the report to standard output, so `inspectra audit -f json > report.json`
always produces valid JSON.

## scan {id="scan"}

```bash
inspectra                                     # same as: inspectra scan
inspectra scan -f sarif -o inspectra.sarif    # for GitHub code scanning
inspectra scan packages/app --fail-on high
inspectra scan -r                             # every package of a monorepo or pub workspace
```

The default command. Runs every project check and prints one report: the [OSV.dev audit](#audit) of `pubspec.lock`,
the pubspec rules, [typosquatting and dependency confusion](#typosquat), and a Trivy filesystem scan with the scanners,
severities and skipped directories of `trivy.filesystem`.

Trivy runs unless `trivy.mode` is `disabled`; `trivy.enabled` does not apply here. In `auto` mode an unavailable Trivy is
skipped with a warning, in `required` mode it is an error. Offline, the dependency confusion check is skipped with a
warning.

| Argument or option | Description |
|:--|:--|
| `[directory]` | The project to scan. Default: the current directory. |
| `-r`, `--recursive` | Also scan nested packages (monorepos and pub workspaces). |

Fails with `1` on any finding unless `--fail-on` or `fail_on` raise the threshold.

## audit {id="audit"}

```bash
inspectra audit
inspectra audit --format json > audit.json
inspectra audit -l app/pubspec.lock --fail-on high
```

Checks every hosted package of `pubspec.lock` against [OSV.dev](https://osv.dev), or the mirror in `network.osv_url`.
Git, path, SDK and private-registry packages are listed as not auditable.

| Option | Description |
|:--|:--|
| `-l`, `--lockfile <path>` | Path to `pubspec.lock`. Default: `pubspec.lock`. |

| Result | Exit code |
|:--|:--|
| No vulnerability at or above the threshold (default: any) | `0` |
| Vulnerabilities at or above the threshold | `1` |
| `pubspec.lock` missing or unreadable | `65` |
| OSV.dev unreachable, or `--offline` | `69` |

## inspect {id="inspect"}

```bash
inspectra inspect http 1.2.0
inspectra inspect http 1.2.0 -f json
```

Downloads the archive of exactly this version from the pub repository, verifies it against its published SHA-256,
reads it in memory and statically analyses the source, the archive structure and the package's own `pubspec.yaml`,
together with the [trust assessment](#trust). Tests, examples and tooling - `inspect.exclude_directories` - are skipped
for code patterns. Tune it in the [`inspect`](Configuration-Reference.md#inspect) section.

| Result | Exit code |
|:--|:--|
| Risk score below `inspect.fail_score` (default 30) | `0` |
| Risk score at or above `inspect.fail_score` | `1` |
| Missing `<package>` or `<version>`, an invalid name or version | `64` |
| Download or verification incomplete | `69` |

## trust {id="trust"}

```bash
inspectra trust http
inspectra trust http 1.2.0
```

Queries pub.dev and prints a trust assessment: first publication, release freshness, retraction, discontinuation,
verified publisher, likes, downloads and pub points. The thresholds are in the
[`trust`](Configuration-Reference.md#trust) section.

| Result | Exit code |
|:--|:--|
| No finding at or above the threshold (default: `critical`) | `0` |
| A finding at or above the threshold | `1` |
| Missing `<package>`, or a package that does not exist | `64` |
| pub.dev unreachable | `69` |

## typosquat {id="typosquat"}

```bash
inspectra typosquat
inspectra typosquat --pubspec app/pubspec.yaml
```

Checks the dependencies declared in `pubspec.yaml` for typosquatting - closeness to popular package names - and for
dependency confusion: private packages whose name also exists on pub.dev. Offline, the confusion check is skipped. Tune
it in the [`typosquat`](Configuration-Reference.md#typosquat) section.

| Option | Description |
|:--|:--|
| `--pubspec <path>` | Path to `pubspec.yaml`. Default: `pubspec.yaml`. |

Fails with `1` on a finding at or above `high` unless `--fail-on` or `fail_on` set another threshold.

## add {id="add"}

```bash
inspectra add http 1.2.0             # audit, then add exactly 1.2.0
inspectra add http                   # the latest version
inspectra add mocktail --dev
inspectra add http 1.2.0 --dry-run   # audit only
```

Audits a package - typosquatting, trust assessment and source inspection - and adds exactly the audited version with
`dart pub add <package>:<version>` (or `flutter pub add`), so the resolver cannot pick a different, unaudited release.
The package is blocked when it looks like a typosquat (`HIGH` or worse), when its trust assessment has a `CRITICAL`
finding, or when its risk score reaches `inspect.fail_score`.

| Option | Description |
|:--|:--|
| `-d`, `--dev` | Add under `dev_dependencies`. |
| `--force` | Install despite reported findings. Never overrides an incomplete verification. |
| `--dry-run` | Audit only; do not modify `pubspec.yaml`. |

| Result | Exit code |
|:--|:--|
| Audited and added, or `--dry-run` without a block | `0` |
| Blocked, and not installed | `1` |
| Missing `<package>`, an invalid name or version, an unknown package | `64` |
| No readable `pubspec.yaml` in the project | `65` |
| Audit incomplete, or `pub add` failed | `69` |

## hook {id="hook"}

```bash
inspectra hook                 # install
inspectra hook install
inspectra hook remove          # or: inspectra hook --remove
```

Installs a Git pre-commit hook that audits a staged `pubspec.lock` and checks a staged `pubspec.yaml` for
typosquatting, in every package of the repository. The hook runs `inspectra` from the `PATH`, or `dart run inspectra`.
It honours `core.hooksPath` and worktrees, and never overwrites a hook it did not install.

| Option | Description |
|:--|:--|
| `--remove` | Remove the hook installed by %product%. |

Exits with `0` once the hook is installed, updated or removed.

## trivy {id="trivy"}

```bash
dart run inspectra trivy                         # configured scans, or a filesystem scan
dart run inspectra trivy secret                  # one scan
dart run inspectra trivy license vulnerability   # several scans
dart run inspectra trivy --where                 # which Trivy would be used
dart run inspectra trivy --install               # make Trivy available, e.g. to warm a CI cache
```

| Arguments | Runs |
|:--|:--|
| none, `trivy.enabled: true` | Every scan whose `enabled` is `true` |
| none, `trivy.enabled: false` | A Trivy filesystem scan of the package, like the Trivy part of [`scan`](#scan), with the scanners, severities and skipped directories of `trivy.filesystem` |
| scan names | Exactly the named scans, in the order secret, license, vulnerability, filesystem - regardless of `enabled` |

Scan names: `secret`, `license`, `vulnerability`, `filesystem`. An unknown name is a usage error.

The configured scans print their summary, write `%report_dir%/<scan>.json` and fail according to each scan's
`fail_on_findings`; see [Reports](Trivy-Reports.md). They need Trivy: when it cannot be provisioned, the command exits
with `69`. The filesystem scan without configured scans follows `trivy.mode` instead and fails on findings at or above
`--fail-on`.

| Option | Description |
|:--|:--|
| `--install` | Only provision Trivy - find it or download it - and print the executable, its version and its origin. |
| `--where` | Only print which Trivy executable would be used, its version and its origin. Never downloads. |

Both accept the [Trivy provisioning options](#shared-options). `--where` only considers executables that already exist -
configured, installed or cached - so it has no side effects. The origin is `configured`, `installed`, `cached` or
`downloaded`. When no Trivy can be provisioned, both print the reason and exit with `69`. A successful lookup prints:

```text
inspectra — Trivy · .
────────────────────────────────────────────────────────────
  Trivy 0.75.0 (cached): /home/me/.cache/inspectra/trivy/0.75.0/trivy
```

## check {id="check"}

```bash
dart run inspectra check
```

Runs every enabled package check in this order and fails if any of them fails:

1. The [format check](#format), when `format.enabled`.
2. The [lint check](#lint), when `lint.enabled`.
3. The [style check](#style), when `style.enabled`.
4. The [API check](#api-check), when `api.enabled`.
5. The [changelog check](#changelog-check), when `changelog.enabled`.
6. Every [enabled Trivy scan](#trivy), when `trivy.enabled`.
7. The [coverage gate](#coverage), when `coverage.enabled`.

All checks run even when an earlier one fails, so one run reports everything; an error such as a missing Trivy stops
the run with its exit code. With nothing enabled it prints
`Nothing is enabled. Enable "format", "lint", "style", "api", "changelog", "trivy" or "coverage" in the Inspectra configuration.`
and exits with `0`.

`check`, `format`, `lint`, `api`, `coverage` and `changelog check` need a `pubspec.yaml` in the package root. They take no shared options;
`INSPECTRA_*` environment variables and `INSPECTRA_CONFIG` apply to them as well. See
[Overriding options](Configuration-Overview.md#overrides).

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
| A file that does not parse, or `dart` cannot be started | `69` |

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

| Result | Exit code |
|:--|:--|
| No diagnostic at or above `lint.fail_on` | `0` |
| Diagnostics at or above `lint.fail_on` | `1` |
| `dart analyze` or `dart fix --apply` did not complete | `69` |

## style {id="style"}

```bash
dart run inspectra style
dart run inspectra style -f sarif -o style.sarif
```

Checks the files selected by `style.include` and `style.exclude` against the built-in rules of `style.preset` and
`style.rules` and the [custom rules](Style-Custom-Rules.md) of `style.custom_rules`, and writes
`.dart_tool/inspectra/style.json`. Runs whether or not `style.enabled` is set. The shared options apply; every
violation is a finding of the source `style` in JSON, SARIF and Markdown. See [Style check](Style-Check.md).

| Result | Exit code |
|:--|:--|
| No violation, or `style.fail_on_findings: false` | `0` |
| Violations | `1` |
| A missing header template or custom rule file, custom rules that do not compile or have invalid ids, an unknown rule in `style.rules` | `65` |
| `dart` cannot be started for the custom rules | `69` |

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

## coverage {id="coverage"}

```bash
dart run inspectra coverage
dart run inspectra coverage --min 85
```

Runs the tests with coverage, writes `lcov.info`, prints the table and checks the threshold. Runs whether or not
`coverage.enabled` is set.

| Option | Description |
|:--|:--|
| `--min <percent>` | The threshold for this run, overriding `coverage.min_line_coverage`. A number from 0 to 100; anything else is a usage error. |

| Result | Exit code |
|:--|:--|
| No threshold, or at or above it | `0` |
| Below the threshold | `1` |
| A test failed, or the runner could not start | `69` |

## changelog generate {id="changelog-generate"}

```bash
dart run inspectra changelog generate
dart run inspectra changelog generate --write
dart run inspectra changelog generate --from v1.0.0 --to main --release 1.1.0 --date 2026-10-04 -f json
```

Reads the commits reachable from `--to` and not from the previous release tag, groups them into the sections of Keep
a Changelog and prints the section of the next release as Markdown. With `--write` it adds the section to
`changelog.file` instead. The suggested version and why it was chosen go to standard error. See
[Changelog](Changelog-Overview.md) and [Commit conventions](Changelog-Commit-Conventions.md).

| Option | Description |
|:--|:--|
| `--from <revision>` | Leave out the commits reachable from this tag, branch or commit. Default: the release tag with the highest version reachable from `--to`; without one, the whole history. |
| `--to <revision>` | Include the commits reachable from this revision. Default: `HEAD`. |
| `--release <version>` | The version to release, with or without a leading `v`. Default: [suggested](Changelog-Commit-Conventions.md#versions) from the commits. |
| `--date <YYYY-MM-DD>` | The release date. Default: today. |
| `--write` | Add the section to `changelog.file` below its introduction and `Unreleased` section, creating the file when it is missing. |

The shared options apply; `-f json` prints the [JSON report](Changelog-Releasing.md#ci) and `-o` writes the output to
a file. Revisions that start with `-` are rejected, so that no value can become an option of `git`.

| Result | Output | Exit code |
|:--|:--|:--|
| Changes to release | The Markdown section, or `✔ Version 1.2.0 added to CHANGELOG.md (5 changes).` with `--write` | `0` |
| Nothing to release | `No changes to release since v1.1.0.`; nothing is written | `0` |
| The version is already in the changelog | `error: … already has a section for version 1.2.0. …` | `64` |
| An invalid `--release` or `--date`, a revision Git cannot resolve, or no release tag and no `version` in `pubspec.yaml` | The cause | `64` |
| Not inside a Git repository | `error: No Git repository found. Run this command inside a Git repository.` | `64` |
| Git is missing or fails, or the changelog cannot be written | The cause | `69` |

In a shallow clone it warns that commits and tags may be missing.

## changelog check {id="changelog-check"}

```bash
dart run inspectra changelog check
```

Validates `changelog.file`: every level two heading is a release or `Unreleased`, versions are semantic versions
listed once and newest first, dates are `YYYY-MM-DD`, and the version of `pubspec.yaml` has a section with text. Runs
whether or not `changelog.enabled` is set; with it, [`check`](#check) runs it too. See
[What changelog check validates](Changelog-Releasing.md#check).

| Result | Output | Exit code |
|:--|:--|:--|
| Valid | `CHANGELOG.md is well-formed and documents version 1.2.0.` | `0` |
| Problems | `CHANGELOG.md has 2 problem(s):`, one line per problem, and how to generate the missing section | `1` |
| `pubspec.yaml` malformed | The cause | `65` |

## changelog notes {id="changelog-notes"}

```bash
dart run inspectra changelog notes
dart run inspectra changelog notes 1.2.0 --output RELEASE_NOTES.md
```

Prints the text of the section of a release, without its heading: the release notes. The version defaults to the one
in `pubspec.yaml` and matches `## 1.2.0`, `## [1.2.0]` and `## v1.2.0` alike. With `-f json` the report holds
`version`, `date` and `notes`.

| Result | Exit code |
|:--|:--|
| The section was printed | `0` |
| No version given and none in `pubspec.yaml` | `64` |
| The changelog is missing, or has no or an empty section for the version | `65` |

## Exit codes {id="exit-codes"}

<include from="lib.topic" element-id="exit-codes"/>

Every exit code other than `0` and `1` comes with a message on standard error naming the cause:

| Message | Exit code |
|:--|:--|
| `error: Could not find a command named "frob".` | `64` |
| `error: inspect requires <package> and <version> arguments.` | `64` |
| `error: --set expects key=value, got "foo".` | `64` |
| `error: --min must be a number between 0 and 100.` | `64` |
| `error: Git cannot resolve the range: fatal: ambiguous argument 'v9..HEAD': unknown revision …` | `64` |
| `error: Invalid Inspectra configuration at "inspectra.trivy.secrets": unknown option. Known options here: …` | `65` |
| `error: Invalid Inspectra configuration at "trivy.secrets": unknown option given on the command line.` | `65` |
| `error: Invalid Inspectra configuration at "nope.yaml": the configuration file does not exist.` | `65` |
| `error: …/pubspec.lock not found. Run "dart pub get" first.` | `65` |
| `error: No pubspec.lock found; run "dart pub get" first.: …` | `65` |
| `error: No pubspec.yaml found; run Inspectra from a package root.: …` | `65` |
| `error: The changelog CHANGELOG.md has no section for version 1.2.0.` | `65` |
| `error: The license header template tool/header.txt (style.license_header) does not exist.` | `65` |
| `error: The custom style rules of style.custom_rules could not be run (dart run exited with 254). …` | `65` |
| `error: Git is not installed or not on the PATH.` | `69` |
| `error: Trivy is not installed and downloading is disabled (trivy.download: false). Trivy is required (trivy.mode: required).` | `69` |
| `error: The configured Trivy executable "…" (trivy.executable) cannot be run.` | `69` |
| `error: Network access is disabled (offline mode), so api.osv.dev cannot be contacted.` | `69` |
| `error: Trivy did not finish scanning …: it exited with 1. This is a failure of Trivy itself, not a finding.` | `69` |
| `error: "dart format" failed with exit code 65.` | `69` |
| `error: "dart analyze" failed with exit code 64.` | `69` |
| `error: "dart test --coverage=…" failed with exit code 1; see its output above.` | `69` |
| `error: Could not start "flutter": …` | `69` |
| `error: internal error: …` | `70` |

## Output streams

Results go to standard output; progress, warnings and errors that prevent a check from running go to standard error.
The test runner's own output during `coverage` is passed through as it is produced.

<seealso>
    <category ref="reference">
        <a href="Builder-Reference.md">Builder reference</a>
        <a href="Library-API.md">Library API</a>
    </category>
    <category ref="config">
        <a href="Configuration-Overview.md#overrides">Overriding options</a>
    </category>
    <category ref="operations">
        <a href="CI-Integration.md">CI integration</a>
        <a href="Troubleshooting.md">Troubleshooting</a>
    </category>
</seealso>
