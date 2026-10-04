# Builder reference

<primary-label ref="builder"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Every build_runner builder Inspectra applies: inputs, outputs, options and rerun behaviour.</link-summary>

<card-summary>inspectra:format, :lint, :api, :secret_scan, :license_scan and :vulnerability_scan in detail.</card-summary>

%product% declares six builders in its `build.yaml`. All of them have `auto_apply: root_package`: they run for the
package you build, never for its dependencies, and need no `build.yaml` of yours.

| Builder | Factory | `build_to` | Output | Runs when |
|:--|:--|:--|:--|:--|
| `inspectra:format` | `formatBuilder` | `cache` | `inspectra/format.json` | `format.enabled`, `format.run_on_build` |
| `inspectra:lint` | `lintBuilder` | `cache` | `inspectra/lint.json` | `lint.enabled`, `lint.run_on_build` |
| `inspectra:style` | `styleBuilder` | `cache` | `inspectra/style.json` | `style.enabled`, `style.run_on_build` |
| `inspectra:api` | `apiBuilder` | `source` | `api/<package>.api` | `api.enabled` |
| `inspectra:secret_scan` | `secretScanBuilder` | `cache` | `inspectra/trivy/secret.json` | `trivy.enabled`, `secret.enabled`, `secret.run_on_build` |
| `inspectra:license_scan` | `licenseScanBuilder` | `cache` | `inspectra/trivy/license.json` | `trivy.enabled`, `license.enabled`, `license.run_on_build` |
| `inspectra:vulnerability_scan` | `vulnerabilityScanBuilder` | `cache` | `inspectra/trivy/vulnerability.json` | `trivy.enabled`, `vulnerability.enabled`, `vulnerability.run_on_build` |

Every builder uses the synthetic `$package$` input and runs at most once per build. When its feature is disabled, it
returns immediately and writes nothing.

## inspectra:format {id="format"}

<deflist type="medium">
    <def title="Order">
        <code>required_inputs: [".dart"]</code>: runs after every builder that outputs Dart files.
    </def>
    <def title="Reads">
        The configuration; every Dart file of the package matching <code>format.include</code> and not
        <code>format.exclude</code>. Outputs that other builders keep in the build cache are skipped.
    </def>
    <def title="Runs">
        <code>dart format --output=none --set-exit-if-changed</code> on those files, in the package root, in batches of
        100.
    </def>
    <def title="Writes">
        The JSON report to the artifact tree, <code>.dart_tool/build/generated/&lt;package&gt;/inspectra/format.json</code>.
    </def>
    <def title="Reruns">
        When a checked file or the configuration changes.
    </def>
</deflist>

## inspectra:lint {id="lint"}

<deflist type="medium">
    <def title="Order">
        <code>required_inputs: [".dart"]</code>: runs after every builder that outputs Dart files, so generated code
        exists when the analyzer looks for it.
    </def>
    <def title="Reads">
        The configuration; every Dart file of the package; <code>analysis_options.yaml</code> when it is a build source.
    </def>
    <def title="Runs">
        <code>dart analyze --format=machine .</code> in the package root.
    </def>
    <def title="Writes">
        <code>.dart_tool/build/generated/&lt;package&gt;/inspectra/lint.json</code>.
    </def>
    <def title="Reruns">
        When a Dart file, the configuration, or - as a build source - <code>analysis_options.yaml</code> changes.
    </def>
</deflist>

## inspectra:style {id="style"}

<deflist type="medium">
    <def title="Order">
        <code>required_inputs: [".dart"]</code>: runs after every builder that outputs Dart files, so that generated
        files it checks exist.
    </def>
    <def title="Reads">
        The configuration; every file of <code>style.include</code> minus <code>style.exclude</code>; the header
        template of <code>style.license_header</code>; the files of <code>style.custom_rules</code>.
    </def>
    <def title="Runs">
        The built-in rules in-process; custom rules through <code>dart run</code> of a generated program, see
        <a href="Style-Custom-Rules.md#how-it-works">How custom rules run</a>.
    </def>
    <def title="Writes">
        <code>.dart_tool/build/generated/&lt;package&gt;/inspectra/style.json</code>.
    </def>
    <def title="Reruns">
        When a checked file, the header template, a custom rule file or the configuration changes.
    </def>
</deflist>

## inspectra:api {id="api"}

<deflist type="medium">
    <def title="Reads">
        <code>pubspec.yaml</code> (configuration), <code>%config_file%</code> (when it is a source), every library
        under <code>lib/</code> outside <code>lib/src/</code> through the resolver - and with it everything those
        libraries import.
    </def>
    <def title="Writes">
        The dump at <code>api.output</code>, by default <code>api/&lt;package&gt;.api</code>, into the package.
    </def>
    <def title="Logs">
        <code>WARNING</code> with a unified diff when the dump changes; <code>INFO</code> when it is written for the
        first time; <code>SEVERE</code> for a broken configuration or a changed <code>api.output</code>.
    </def>
    <def title="Reruns">
        When a public library, anything it imports, or <code>pubspec.yaml</code> changes.
    </def>
</deflist>

### Options

The output location is normally taken from the configuration. In a `build.yaml`, the builder option `output`
overrides it - useful only for tests of the builder itself:

```yaml
targets:
  $default:
    builders:
      inspectra:api:
        options:
          output: api/public.api
```

### --only-check

`dart run build_runner build --only-check` runs the builder, writes nothing, and fails when the dump on disk differs
from what it would write. See [Workflow](API-Workflow.md#checking-in-ci).

## inspectra:secret_scan {id="secret-scan"}

<deflist type="medium">
    <def title="Reads">
        The configuration; every build source matching <code>secret.include</code> and not <code>secret.exclude</code>;
        <code>%secret_config%</code> when it is a source.
    </def>
    <def title="Runs">
        One <code>trivy fs --scanners secret</code> over a staging copy of the selected files.
    </def>
    <def title="Writes">
        The JSON report to the artifact tree, <code>%artifact_dir%/secret.json</code>.
    </def>
    <def title="Reruns">
        When a scanned file changes, a matching file is added or removed, or the configuration changes.
    </def>
</deflist>

## inspectra:license_scan {id="license-scan"}

<deflist type="medium">
    <def title="Reads">
        The configuration and <code>pubspec.lock</code> through the build step; <code>.dart_tool/package_config.json</code>
        and the dependencies' <code>pubspec.yaml</code> and license files from disk.
    </def>
    <def title="Runs">
        One <code>trivy fs --scanners license --license-full</code> over the staged license files.
    </def>
    <def title="Writes">
        <code>%artifact_dir%/license.json</code>.
    </def>
    <def title="Reruns">
        When <code>pubspec.lock</code> or the configuration changes - that is, when dependencies change.
    </def>
</deflist>

## inspectra:vulnerability_scan {id="vulnerability-scan"}

<deflist type="medium">
    <def title="Reads">
        The configuration and <code>pubspec.lock</code>; with <code>include_dev_dependencies: false</code> also the
        package graph from disk.
    </def>
    <def title="Runs">
        One <code>trivy fs --scanners vuln</code> over a staging copy of the lock file.
    </def>
    <def title="Writes">
        <code>%artifact_dir%/vulnerability.json</code>.
    </def>
    <def title="Reruns">
        When <code>pubspec.lock</code> or the configuration changes - not when the Trivy database does.
    </def>
</deflist>

## Logging

| Level | When |
|:--|:--|
| `SEVERE` | A format or lint check failed, a scan failed, the configuration is broken, Trivy is missing or failed, the package is not resolved, `api.output` changed during `watch`. The build fails. |
| `WARNING` | Findings or diagnostics that do not fail, an API change, `%config_file%` that is not a build source. |
| `INFO` | The first API dump. Shown with `--verbose`. |
| `FINE` | A clean scan or check. Shown with `--verbose`. |

## Disabling a builder

Every builder does nothing until its feature is enabled. To switch one off for a package even when the configuration
enables the feature - for example in one member of a workspace - disable it in that package's `build.yaml`:

```yaml
targets:
  $default:
    builders:
      inspectra:vulnerability_scan:
        enabled: false
```

<seealso>
    <category ref="reference">
        <a href="CLI-Reference.md">Command line reference</a>
    </category>
    <category ref="config">
        <a href="Build-Sources.md">Build sources</a>
    </category>
    <category ref="start">
        <a href="How-It-Works.md">How it works</a>
    </category>
    <category ref="external">
        <a href="https://github.com/dart-lang/build/blob/master/docs/build_yaml_format.md">build.yaml format</a>
    </category>
</seealso>
