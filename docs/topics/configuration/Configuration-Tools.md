# Configuration tools

<primary-label ref="cli"/>
<secondary-label ref="no-network"/>
<secondary-label ref="since-1-1"/>

<show-structure for="chapter" depth="2"/>

<link-summary>See where every configuration value comes from, validate the configuration and its files, lint it for risky settings, and get completion in the editor.</link-summary>

<card-summary>config show --explain, config validate, config lint and a JSON Schema for completion and validation in the editor.</card-summary>

<tldr>
<p><b>Where does a value come from?</b> <code>dart run %package% config show --explain</code></p>
<p><b>Is the configuration complete?</b> <code>dart run %package% config validate</code></p>
<p><b>Is it risky?</b> <code>dart run %package% config lint</code></p>
<p><b>Editor</b>: <code># yaml-language-server: $schema=…/inspectra.schema.json</code> in <code>%config_file%</code></p>
</tldr>

The effective configuration of a package is layered: the built-in defaults, the configuration file, `INSPECTRA_*`
environment variables set by a CI system or a developer's shell, and the command line. In a large organisation the
question "which value applies here, and who set it?" is asked often and answered slowly. The `config` commands answer
it, and catch the mistakes that the strict validation cannot see: a misspelled environment variable, a file the
configuration names but that does not exist, a setting that silently weakens a gate.

## config show {id="show"}

```bash
dart run %package% config show --explain
```

Prints the effective configuration as YAML, with the same keys as `%config_file%`. Options without a value are
commented out. With `--explain`, every value says where it comes from:

```yaml
# The effective Inspectra configuration: inspectra.yaml and its overrides.
lint:
  enabled: true                      # inspectra.yaml:3
  fail_on: warning                   # inspectra.yaml:4
trivy:
  mode: required                     # environment variable INSPECTRA_TRIVY_MODE
  version: latest                    # command line
  timeout: 10m                       # default
  # executable:                      # unset
```

`config show` reads the configuration exactly like the other commands: `--config`, `--set` and the Trivy flags apply,
so `config show --set trivy.version=latest` shows what `scan --set trivy.version=latest` would use. `--only-changed`
leaves out every value that is the default - the shortest description of what a package configures. With `-f json`,
`values` holds one object per option with `key`, `value`, `default`, `origin` (`default`, `file`, `environment` or
`commandLine`) and, where known, `variable` and `line`.

## config validate {id="validate"}

```bash
dart run %package% config validate
```

Loads the configuration - an unknown key or a wrong type fails with exit code `65`, naming the key and the closest
valid option - and checks that every file it refers to exists: `style.license_header`, `style.custom_rules`,
`trivy.secret.config`, `network.ca_certificates` and, with `changelog.enabled`, `changelog.file`. A baseline file must
be well-formed. All problems are listed at once:

```text
error: The configuration has 2 problem(s):
  style.license_header: the file tool/header.txt does not exist.
  network.ca_certificates: the file certs/corp-ca.pem does not exist.
```

Run it in a pre-commit hook or as the first CI step: it is fast, needs no network and fails before any scan starts.

## config lint {id="lint"}

```bash
dart run %package% config lint
dart run %package% config lint -f sarif -o config.sarif
```

Reports settings that are valid but risky, as findings of the source `config` located at their line in the
configuration file. The shared options apply: `--fail-on`, `-f json|sarif|markdown`, and documented exceptions in
`ignore` like for any finding.

| Rule | Severity | Reported when |
|:--|:--|:--|
| `CONFIG_INSECURE_URL` | high | `network.osv_url`, `network.pub_hosted_url`, `trivy.download_base_url` or `trivy.latest_release_url` uses `http://` |
| `CONFIG_UNKNOWN_VARIABLE` | medium | An `INSPECTRA_*` environment variable names no option and is ignored; the closest option is suggested |
| `CONFIG_TRIVY_DISABLED` | medium | `trivy.mode: disabled` |
| `CONFIG_UNPINNED_TRIVY` | medium | `trivy.version: latest` makes runs of the same commit use different Trivy releases |
| `CONFIG_IGNORE_EXPIRED` | medium | An ignore rule expired and no longer suppresses anything |
| `CONFIG_IGNORE_WITHOUT_EXPIRY` | low | An ignore rule has no `expires` date |
| `CONFIG_GATE_NOT_FAILING` | low | An enabled check has `fail_on_findings: false`, or `lint.fail_on: none` |
| `CONFIG_MIN_SEVERITY` | low | `min_severity` hides findings from every report |
| `CONFIG_NO_COVERAGE_THRESHOLD` | low | `coverage.enabled` without `min_line_coverage` |
| `CONFIG_BASELINE_UNBOUNDED` | low | A [baseline](Baseline.md) file exists and `baseline.max_severity` is unset |
| `CONFIG_PUBSPEC_SECTION_IGNORED` | medium | `pubspec.yaml` has an `inspectra:` section, but a configuration file replaces it, with its `extends` and `policy` |

The environment variables `INSPECTRA_CONFIG`, `INSPECTRA_TRIVY`, `INSPECTRA_DEBUG` and `INSPECTRA_CACHE_DIR` are read
by %product% itself and never reported. A misspelled variable is the most common configuration mistake in CI, because
nothing fails - the option just keeps its default:

```text
[MEDIUM]   The environment variable INSPECTRA_TRIVY_VERSON names no option and is ignored  (CONFIG_UNKNOWN_VARIABLE)
    Inspectra reads INSPECTRA_ followed by the upper case option path, such as INSPECTRA_TRIVY_VERSION for trivy.version. Did you mean "INSPECTRA_TRIVY_VERSION"?
```

## config fetch {id="fetch"}

```bash
dart run %package% config fetch
```

Downloads the remote bases that the configuration [extends](Configuration-Inheritance.md), verifies them against their
SHA-256 and caches them, so that later runs, `build_runner` and machines without network access can use them. Every
command does this before reading the configuration; `config fetch` only lists the bases afterwards:

```text
✓ package:acme_policy/inspectra.yaml (package, available)
✓ https://policy.acme.corp/flutter/v3.yaml (remote, downloaded)
2 base(s) ready, 1 downloaded.
```

`config show --explain` comments values from a base with that base and its line, such as
`# package:acme_policy/inspectra.yaml:4`, and `config show -f json` adds `layers` and a `file` per value.

## Editor support with the JSON Schema {id="schema"}

```bash
dart run %package% config schema -o inspectra.schema.json
```

`config schema` prints the JSON Schema (draft-07) of `%config_file%`. It is generated from the options the
configuration actually reads, with their types, allowed values, ranges and defaults, so it never drifts from the
code; it also works while the project's configuration is broken. The schema of each release is published in the
repository, so a modeline at the top of `%config_file%` is enough for VS Code with the YAML extension, IntelliJ IDEA
and every other editor that uses the YAML language server:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/davils-com/Inspectra/main/inspectra.schema.json
trivy:
  enabled: true
```

The editor then completes keys, shows defaults, and underlines unknown keys and invalid values as you type. For a
schema that matches the installed version exactly, generate it into the repository and point the modeline at the
file. The `inspectra:` section of `pubspec.yaml` is not covered, because a schema applies to a whole file.

<seealso>
    <category ref="config">
        <a href="Configuration-Overview.md">Where the configuration lives</a>
        <a href="Configuration-Reference.md">Configuration reference</a>
        <a href="Baseline.md">Baseline</a>
    </category>
    <category ref="reference">
        <a href="CLI-Reference.md#config-show">config show, validate, lint and schema</a>
    </category>
    <category ref="external">
        <a href="https://json-schema.org/">JSON Schema</a>
        <a href="https://github.com/redhat-developer/yaml-language-server">YAML language server</a>
    </category>
</seealso>
