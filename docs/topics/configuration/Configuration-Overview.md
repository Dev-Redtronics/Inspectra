# Where the configuration lives

<primary-label ref="config"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Where the configuration can live, which one wins, how options are overridden, and how it is validated.</link-summary>

<card-summary>pubspec.yaml or inspectra.yaml, --set and INSPECTRA_* overrides, strict validation, and error messages that name the key.</card-summary>

<tldr>
<p><b>Recommended</b>: an <code>%pubspec_key%:</code> section in <code>pubspec.yaml</code></p>
<p><b>Alternative</b>: <code>%config_file%</code> in the package root, same keys without the <code>%pubspec_key%:</code> level</p>
<p><b>Precedence</b>: <code>%config_file%</code> wins when it exists</p>
<p><b>Overrides</b>: <code>--set key=value</code> and flags, then <code>INSPECTRA_&lt;PATH&gt;</code> variables, then the file</p>
<p><b>Validation</b>: unknown keys and wrong types are errors</p>
</tldr>

## Two locations, one format

The whole configuration of %product% is one YAML mapping with snake_case keys:

- the supply-chain commands (`scan`, `audit`, `inspect`, `trust`, `typosquat`, `add`, `hook`) are tuned by `fail_on`,
  `min_severity`, `ignore`, `network`, `inspect`, `trust` and `typosquat`;
- the package checks are configured in `format`, `lint`, `style`, `api`, `changelog`, `trivy` and `coverage`; `trivy`
  also decides how
  Trivy is provisioned for every command that runs it.

It can live in either of two places.

<tabs group="config-location">
    <tab title="pubspec.yaml" group-key="pubspec">
        <code-block lang="yaml"><![CDATA[
            name: my_package
            version: 1.0.0

            dev_dependencies:
              %package%: ^%version%

            %pubspec_key%:
              api:
                enabled: true
              trivy:
                enabled: true
              coverage:
                enabled: true
                min_line_coverage: 80
        ]]></code-block>
    </tab>
    <tab title="inspectra.yaml" group-key="file">
        <code-block lang="yaml"><![CDATA[
            # inspectra.yaml, next to pubspec.yaml
            api:
              enabled: true
            trivy:
              enabled: true
            coverage:
              enabled: true
              min_line_coverage: 80
        ]]></code-block>
    </tab>
</tabs>

The keys are the same; only the `%pubspec_key%:` level is dropped in `%config_file%`. Pub ignores top-level keys it
does not know, so the section in `pubspec.yaml` does not disturb `dart pub get` or `dart pub publish`.

### Which one wins

1. A file named with `--config <path>`, or else with the environment variable `INSPECTRA_CONFIG`, relative to the
   package root. It must exist.
2. If `%config_file%` exists in the package root, it is the whole configuration. The `%pubspec_key%:` section of
   `pubspec.yaml` is then ignored entirely - the two are not merged.
3. Otherwise the `%pubspec_key%:` section of `pubspec.yaml` is used.
4. Without either, every default applies: every package check is off, and the supply-chain commands run with their
   defaults.

The package name always comes from `pubspec.yaml`; it is used for the default name of the API dump.

### Which one to choose

<compare first-title="pubspec.yaml section" second-title="inspectra.yaml">
<code-block lang="yaml"><![CDATA[
# + Always a build_runner source: editing it
#   reruns the builders.
# + One file less in the repository.
# - Mixed with the package metadata.
inspectra:
  trivy:
    enabled: true
]]></code-block>
<code-block lang="yaml"><![CDATA[
# + A file of its own, easy to find and review.
# - Not a build_runner source by default: edits
#   rerun nothing until you add it to build.yaml.
trivy:
  enabled: true
]]></code-block>
</compare>

The section in `pubspec.yaml` is recommended when you use the builders. `build_runner` only tracks
<tooltip term="build source">build sources</tooltip>, and `pubspec.yaml` always is one, while `%config_file%` is not.
With `%config_file%`, %product%'s builders read it from disk, log a warning once per build, and an edit takes effect
only with the next build that has another reason to rerun. [Build sources](Build-Sources.md) shows how to add it to
the sources so that this does not happen.

<warning>
The command line always reads the current files, so <code>dart run %package% check</code> is never affected. The caveat
applies to <code>dart run build_runner build</code> and <code>watch</code> only.
</warning>

## Overriding options {id="overrides"}

Every option can be set without editing the file. For each key, the first of these that defines it wins:

1. **The command line**: `--set <path>=<value>`, repeatable, and the dedicated flags `--fail-on`, `--min-severity`,
   `--offline`, `--trivy-mode`, `--trivy-version`, `--trivy-executable`, `--[no-]trivy-download` and
   `--[no-]trivy-use-installed`. Only the commands with [shared options](CLI-Reference.md#shared-options) accept them.
2. **The environment**: `INSPECTRA_` followed by the dotted path in upper case, with dots turned into underscores.
3. **The configuration file**.
4. **The built-in default**.

| Key | Command line | Environment variable |
|:--|:--|:--|
| `trivy.version` | `--set trivy.version=latest`, `--trivy-version latest` | `INSPECTRA_TRIVY_VERSION=latest` |
| `trivy.download_base_url` | `--set trivy.download_base_url=https://…` | `INSPECTRA_TRIVY_DOWNLOAD_BASE_URL=https://…` |
| `network.proxy` | `--set network.proxy=http://proxy.corp:3128` | `INSPECTRA_NETWORK_PROXY=http://proxy.corp:3128` |
| `network.offline` | `--offline` | `INSPECTRA_NETWORK_OFFLINE=true` |
| `fail_on` | `--fail-on high` | `INSPECTRA_FAIL_ON=high` |
| `trivy.filesystem.scanners` | `--set trivy.filesystem.scanners=vuln,secret` | `INSPECTRA_TRIVY_FILESYSTEM_SCANNERS=vuln,secret` |

```bash
INSPECTRA_TRIVY_VERSION=latest inspectra scan
inspectra scan --set trivy.mode=required --set network.timeout=60s
INSPECTRA_TRIVY_ENABLED=true dart run inspectra check
```

`inspectra config show --explain` prints the effective value of every option with the layer it comes from - the file
and line, an environment variable, the command line or the default. See [Configuration tools](Configuration-Tools.md).

- A list is written comma-separated. A boolean accepts `true`, `yes`, `1`, `on` and `false`, `no`, `0`, `off`.
  Durations are written as `500ms`, `30s`, `10m` or `1h`.
- Overridden values are validated like the file: `--set trivy.mode=sometimes` is an error.
- A `--set` key that is not an option is an error; an `INSPECTRA_*` variable that matches no option is ignored, and
  [`config lint`](Configuration-Tools.md#lint) reports it with the option it probably meant.
- The `ignore` list can only be written in the file, and sections cannot be replaced as a whole.
- `INSPECTRA_TRIVY` sets `trivy.executable` for compatibility: it wins over the file and over
  `INSPECTRA_TRIVY_EXECUTABLE`, but not over `--trivy-executable` or `--set trivy.executable=…`.
- `check`, `format`, `lint`, `api`, `coverage` and `changelog check` take no `--set`; the environment variables apply to
  them as well. `style` takes `--set` like the supply-chain commands.

## Defaults

Every option has a default, and the defaults are chosen so that the smallest useful configuration is one line per
feature:

| Section | Off by default | What enabling it does |
|:--|:--|:--|
| `format` | `enabled: false` | `check` runs the format check; with `run_on_build`, every build does |
| `lint` | `enabled: false` | `check` runs the lint check; with `run_on_build`, every build does |
| `api` | `enabled: false` | The API builder writes the dump; `api check` and `check` verify it |
| `trivy` | `enabled: false` | The secret, license and vulnerability scans run; the filesystem scan stays off |
| `coverage` | `enabled: false` | `check` runs the coverage gate; there is no threshold until you set one |

The supply-chain sections need no switch: `scan`, `audit` and the other supply-chain commands work without any
configuration, and the sections only tune them.

Within `trivy`, the secret, license and vulnerability scans default to `enabled: true` - they are off only because
`trivy.enabled` is. The filesystem scan defaults to `enabled: false`, because it overlaps with the other three and
scans the whole package. See the [configuration reference](Configuration-Reference.md) for every default.

## Validation {id="validation"}

Every key is checked when the configuration is loaded - in each build step and at the start of each command.
%product% rejects:

<deflist type="medium">
    <def title="Unknown keys">
        A key that is not an option at its position, such as a misspelling. The error lists the options that are
        valid there.
    </def>
    <def title="Wrong types">
        A string where a boolean is expected, a single value where a list is expected, and so on.
    </def>
    <def title="Values outside their range">
        A severity that does not exist, a lint level other than error, warning, info or none, a page width that is not
        a whole number from 1 to 1000, a scanner Trivy does not know, an empty list of severities or scanners, a
        coverage threshold outside 0 to 100, an unknown test runner.
    </def>
    <def title="Empty strings">
        In paths, globs and names; an empty value is always a mistake.
    </def>
    <def title="Malformed YAML">
        With the line and column of the syntax error.
    </def>
</deflist>

Each error names the key by its full path, starting at `%pubspec_key%` for the `pubspec.yaml` section and at the top
level for `%config_file%`. List elements are addressed by index:

```text
Invalid Inspectra configuration at "inspectra.trivy.secrets": unknown option. Did you mean "secret"? Known options here: cache_directory, connectivity_timeout, db_repository, download, download_base_url, enabled, executable, extra_args, filesystem, install_directory, latest_release_url, license, mode, report_directory, secret, skip_db_update, timeout, use_installed, version, vulnerability.
Invalid Inspectra configuration at "inspectra.trivy.enabled": expected true or false, got "yes please".
Invalid Inspectra configuration at "inspectra.trivy.vulnerability.severity[1]": expected one of CRITICAL, HIGH, MEDIUM, LOW, UNKNOWN, got "SEVERE".
Invalid Inspectra configuration at "inspectra.coverage.min_line_coverage": expected a number between 0.0 and 100.0, got 120.
Invalid Inspectra configuration at "inspectra.fail_on": expected one of critical, high, medium, low, unknown, got "severe".
Invalid Inspectra configuration at "inspectra.network.timeout": expected a duration such as 30s, 10m or 1h, got "5 minutes".
Invalid Inspectra configuration at "inspectra.yaml": line 2, column 1: While parsing a flow sequence, expected ',' or ']'.
Invalid Inspectra configuration at "trivy.secrets.enabled": unknown option given on the command line. Did you mean "trivy.secret.enabled"?
```

An unknown key comes with the closest valid option as a suggestion, when one is close. An `ignore` entry without `id`
or `reason` is rejected as well: every suppression must be justified. `inspectra config validate` additionally checks
that every file the configuration refers to exists, and editors validate as you type with the
[JSON Schema](Configuration-Tools.md#schema).

<note>
The strictness is deliberate. A misspelled <code>secrets:</code> instead of <code>secret:</code> would otherwise leave
the secret scan on its defaults without any sign that your settings were never read - the kind of mistake that is
found only after a credential leaked.
</note>

### Where an error surfaces

| Run | Effect of a broken configuration |
|:--|:--|
| `dart run build_runner build` | Every %product% builder logs the error as `SEVERE`; the build fails |
| `dart run %package% …` | The error is printed to standard error; exit code `65` |
| `package:%package%` | `loadConfig` and `InspectraConfig.parse` throw `InspectraConfigException` |

## YAML notes

- Booleans are `true` and `false`. YAML 1.2 does not treat `yes`, `no`, `on` or `off` as booleans, so `enabled: yes`
  is a string and an error.
- Lists can be written in block or flow style; `severity: [CRITICAL, HIGH]` and the block form are the same.
- Globs and paths are relative to the package root and always use `/`, on Windows too.
- Quote globs that start with `*`, because an unquoted `*` starts a YAML alias: `'**.dart'`, not `**.dart`.

<seealso>
    <category ref="config">
        <a href="Configuration-Reference.md">Configuration reference</a>
        <a href="Build-Sources.md">Build sources</a>
    </category>
    <category ref="start">
        <a href="Getting-Started.md">Getting started</a>
    </category>
    <category ref="reference">
        <a href="Library-API.md">Library API</a>
    </category>
</seealso>
