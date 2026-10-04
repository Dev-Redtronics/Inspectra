# Lint check

<primary-label ref="builder"/>
<secondary-label ref="opt-in"/>
<secondary-label ref="no-network"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Static analysis with dart analyze and the rules of analysis_options.yaml, as a gate.</link-summary>

<card-summary>Errors, warnings and lints as one check, failing from the level you choose, with --fix.</card-summary>

<tldr>
<p><b>Enable</b>: <code>lint: { enabled: true }</code></p>
<p><b>Check</b>: <code>dart run %package% lint</code> · <b>Fix</b>: <code>dart run %package% lint --fix</code></p>
<p><b>Fails on</b>: infos and above by default, like <code>dart analyze --fatal-infos</code></p>
<p><b>Rules</b>: your <code>analysis_options.yaml</code>, or the <a href="Lint-Preset.md">lint preset</a></p>
</tldr>

The lint check runs the Dart analyzer over the package and reports every
<tooltip term="diagnostic">diagnostic</tooltip>: compile-time errors, warnings, hints and the lints enabled in
`analysis_options.yaml`. It fails from a severity you choose.

## Configuration

```yaml
inspectra:
  lint:
    enabled: true          # default false
    run_on_build: false    # default
    fail_on: info          # default; error, warning, info or none
```

| Key | Default | Description |
|:--|:--|:--|
| `enabled` | `false` | Whether `check` runs the lint check. `dart run %package% lint` runs it regardless. |
| `run_on_build` | `false` | Whether `build_runner build` runs it. |
| `fail_on` | `info` | The lowest severity that fails the check. |

### fail_on

| Value | Fails on | Same as |
|:--|:--|:--|
| `error` | Errors | `dart analyze --no-fatal-warnings` |
| `warning` | Errors and warnings | `dart analyze` |
| `info` | Errors, warnings and infos - which includes every lint | `dart analyze --fatal-infos` |
| `none` | Nothing; everything is reported | |

Every diagnostic is reported whatever `fail_on` says; it only decides which ones fail. Lints are infos by default.
To make a single rule fail a lenient check, or to silence one, change its severity in `analysis_options.yaml`:

```yaml
analyzer:
  errors:
    unused_import: error          # fails even with fail_on: error
    todo: ignore                  # never reported
```

## Which rules apply

The check runs `dart analyze` in the package root, so everything in `analysis_options.yaml` applies:

- `include:` - for example [Inspectra's lint preset](Lint-Preset.md), `package:lints/recommended.yaml` or
  `package:flutter_lints/flutter.yaml`,
- `linter: rules:` - the lint rules,
- `analyzer: exclude:` - files that are not analyzed, such as generated code,
- `analyzer: errors:` - severity changes,
- `analyzer: language:` - `strict-casts`, `strict-inference`, `strict-raw-types`.

%product% adds no rules of its own on top. The lint check is a gate around your analysis configuration, and the
preset is one configuration you can choose.

## Running it

<tabs group="run">
    <tab title="Command line" group-key="cli">
        <code-block lang="bash"><![CDATA[
dart run inspectra lint          # analyze
dart run inspectra lint --fix    # dart fix --apply, then analyze
dart run inspectra check         # includes the check when lint.enabled
]]></code-block>
    </tab>
    <tab title="build_runner" group-key="build">
        <code-block lang="yaml"><![CDATA[
inspectra:
  lint:
    enabled: true
    run_on_build: true
]]></code-block>
        <code-block lang="bash"><![CDATA[
dart run build_runner build
]]></code-block>
    </tab>
</tabs>

### Output

```text
Lint: 5 issue(s) - 1 error(s), 1 warning(s), 3 info(s).
  [ERROR] lib/a.dart:3:11: invalid_assignment - A value of type 'String' can't be assigned to a variable of type 'int'.
  [WARNING] lib/a.dart:3:7: unused_local_variable - The value of the local variable 'y' isn't used.
  [INFO] lib/a.dart:2:11: prefer_single_quotes - Unnecessary use of double quotes.
  [INFO] lib/a.dart:3:11: prefer_single_quotes - Unnecessary use of double quotes.
  [INFO] lib/c.dart:2:11: prefer_single_quotes - Unnecessary use of double quotes.
```

Errors come first, then warnings and infos, each sorted by file and position. Each line has the form
`[SEVERITY] file:line:column: code - message`, and the code is the name to use in `analysis_options.yaml` or in an
`// ignore:` comment.

The command line writes `.dart_tool/inspectra/lint.json`:

```json
{
  "check": "lint",
  "failed": true,
  "fail_on": "info",
  "issues": [
    {
      "severity": "error",
      "type": "COMPILE_TIME_ERROR",
      "code": "invalid_assignment",
      "path": "lib/a.dart",
      "line": 3,
      "column": 11,
      "message": "A value of type 'String' can't be assigned to a variable of type 'int'."
    }
  ]
}
```

### --fix

`dart run %package% lint --fix` runs `dart fix --apply` first, which applies every automatic fix the analyzer offers -
for most lints there is one - and then analyzes the result. What is left needs a person.

<warning>
<code>dart fix --apply</code> changes your files. Run it on a clean working tree, read the diff, and run the tests.
</warning>

## On build

With `run_on_build: true`, the `inspectra:lint` builder runs `dart analyze` on every `build_runner build`:

- It declares `.dart` as a required input, so it runs **after every builder that generates Dart code** - the analysis
  sees the generated `.g.dart` files instead of reporting them as missing.
- It reads every Dart file of the package, and `analysis_options.yaml` when that is a build source, so it reruns when
  code or rules change.
- Findings that fail are a `SEVERE` log entry and fail the build; others are a warning.

```text
E inspectra:lint on $package$:
  Lint: 1 issue(s) - 0 error(s), 0 warning(s), 1 info(s).
    [INFO] lib/src/new_feature.dart:1:14: prefer_single_quotes - Unnecessary use of double quotes.
```

<note>
<code>analysis_options.yaml</code> is not a build source by default. Add it to the sources in <code>build.yaml</code>
so that a changed rule set reruns the builder - see <a href="Build-Sources.md">Build sources</a>.
</note>

## Errors

`dart analyze` exits with 0 to 3 for a completed analysis; anything else - the SDK cannot be started, the analysis
crashed - is an error: the command exits with `69`, and the builder logs `SEVERE`. A failing `dart fix --apply` is an
error as well.

<seealso>
    <category ref="quality">
        <a href="Lint-Preset.md">Lint preset</a>
        <a href="Format-Check.md">Format check</a>
    </category>
    <category ref="config">
        <a href="Configuration-Reference.md#lint">Configuration reference</a>
    </category>
    <category ref="external">
        <a href="https://dart.dev/tools/analysis">Customizing static analysis</a>
        <a href="https://dart.dev/tools/linter-rules">Linter rules</a>
        <a href="https://dart.dev/tools/dart-fix">dart fix</a>
    </category>
</seealso>
