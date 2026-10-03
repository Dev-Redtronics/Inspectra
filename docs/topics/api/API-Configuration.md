# API configuration

<primary-label ref="config"/>
<secondary-label ref="opt-in"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Enabling the dump, choosing its location, and keeping libraries and declarations out of it.</link-summary>

<card-summary>enabled, output, ignored_libraries and non_public_annotations, with examples.</card-summary>

```yaml
inspectra:
  api:
    enabled: true
    output: api/<package>.api                 # default
    ignored_libraries: []                     # default
    non_public_annotations: [internal, visibleForTesting]   # default
```

## enabled

`false` by default. When `true`:

- the `inspectra:api` builder writes the dump on every `build_runner` build,
- `dart run %package% check` runs the API check,
- `dart run %package% api dump` and `api check` work - they also work when it is `false`, if you call them
  explicitly.

## output

The dump file, relative to the package root. The default is `api/` plus the `name` from `pubspec.yaml` plus `.api`.

```yaml
inspectra:
  api:
    enabled: true
    output: doc/public-api.txt
```

<warning>
<code>build_runner</code> asks each builder for its outputs before the build starts, so the builder reads
<code>output</code> once, when <code>build_runner</code> starts. After changing it, restart
<code>build_runner watch</code> or <code>serve</code>; until then, the builder logs
<i>api.output changed from "…" to "…". Restart build_runner so that it picks up the new location.</i> and writes
nothing. A plain <code>build</code> starts fresh each time and is not affected.
</warning>

## ignored_libraries

Globs of public libraries to leave out entirely, relative to the package root:

```yaml
inspectra:
  api:
    enabled: true
    ignored_libraries:
      - lib/testing.dart          # test helpers for consumers, no stability promise
      - lib/experimental/**       # explicitly unstable
```

Use it for libraries that are public for technical reasons but carry no compatibility promise. Declarations those
libraries share with other public libraries still appear in the others' sections.

## non_public_annotations

Annotations that keep a declaration or member out of the dump. Each entry matches either the name of a constant used
as an annotation, or the name of an annotation class:

| Entry | Matches |
|:--|:--|
| `internal` | `@internal` from `package:meta` |
| `visibleForTesting` | `@visibleForTesting` from `package:meta` |
| `Internal` | `@Internal()`, an instance of a class named `Internal` |
| `experimental` | `@experimental` from `package:meta` |

The defaults are `internal` and `visibleForTesting`:

<deflist type="medium">
    <def title="@internal">
        <code>package:meta</code>'s marker for declarations that are public only so that other libraries of the same
        package can use them. The analyzer warns when another package uses them.
    </def>
    <def title="@visibleForTesting">
        Public only for tests. Consumers using it get an analyzer warning.
    </def>
</deflist>

Replace the list to change it; to keep the defaults, repeat them:

```yaml
inspectra:
  api:
    enabled: true
    non_public_annotations: [internal, visibleForTesting, experimental]
```

<note>
Matching is by name only, so your own <code>const internal = Object();</code> matches <code>internal</code> as well.
That is usually what you want: a project-specific marker works without configuration if it has the same name.
</note>

## Keeping things out of the API without configuration

Before reaching for these options, consider the language's own tools - they also keep the analyzer and pub's scoring
honest:

1. **Move it to `lib/src/`** and do not export it.
2. **Make it private** with a leading underscore.
3. **Narrow an export** with `show` or `hide`: `export 'src/impl.dart' show Client;`.

<seealso>
    <category ref="api">
        <a href="API-Overview.md">Public API validation</a>
        <a href="API-Dump-Format.md">Dump format</a>
    </category>
    <category ref="config">
        <a href="Configuration-Reference.md#api">Configuration reference</a>
    </category>
    <category ref="external">
        <a href="https://pub.dev/documentation/meta/latest/meta/meta-library.html">package:meta annotations</a>
    </category>
</seealso>
