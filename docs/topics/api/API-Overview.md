# Public API validation

<primary-label ref="builder"/>
<secondary-label ref="opt-in"/>
<secondary-label ref="no-network"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>A committed dump of your public API, so that every API change is a reviewed decision.</link-summary>

<card-summary>api/&lt;package&gt;.api: what consumers can use, kept up to date by build_runner and checked in CI.</card-summary>

<tldr>
<p><b>Enable</b>: <code>api: { enabled: true }</code></p>
<p><b>Dump</b>: <code>dart run build_runner build</code> or <code>dart run %package% api dump</code></p>
<p><b>Check</b>: <code>dart run build_runner build --only-check</code> or <code>dart run %package% api check</code></p>
<p><b>File</b>: <code>api/&lt;package&gt;.api</code>, committed</p>
</tldr>

A package's public API is a promise to everyone who depends on it. Breaking it is easy - removing a parameter, making
a class `final`, renaming a getter, changing a default value - and none of these look dangerous in a source diff
scattered across `lib/src`. They look like ordinary edits.

Public API validation makes them visible. %product% renders everything your
<tooltip term="public library">public libraries</tooltip> export into one sorted text file that you commit. From then
on:

- every build updates the file and logs the change as a diff,
- every pull request that changes the API changes that file, where a reviewer sees it,
- CI fails when the code exports something different from what the committed file says.

```diff
   bool operator ==(Object other);
   int compareTo(Shape other);
-  abstract Shape scale(double factor);
+  abstract Shape scale(double factor, {bool keepLabel = true});
   @Deprecated double surface();
 }
```

## Quick start

<procedure title="Record and check the API" id="record-and-check">
    <step>
        <p>Enable it:</p>
        <code-block lang="yaml"><![CDATA[
inspectra:
  api:
    enabled: true
]]></code-block>
    </step>
    <step>
        <p>Record the current API:</p>
        <code-block lang="bash"><![CDATA[
dart run build_runner build
]]></code-block>
    </step>
    <step>
        <p>Review and commit <code>api/&lt;package&gt;.api</code>.</p>
    </step>
    <step>
        <p>Check it in CI:</p>
        <code-block lang="bash"><![CDATA[
dart run build_runner build --only-check
]]></code-block>
    </step>
</procedure>

## What counts as public

The public API of a Dart package is what another package can import and use:

1. **Public libraries**: every Dart file under `lib/` that is not under `lib/src/` and is a library, not a `part`.
   `lib/src` is private by convention, and pub enforces it with the `implementation_imports` lint.
2. **Their <tooltip term="export namespace">export namespace</tooltip>**: what each library declares, plus what it
   re-exports from `lib/src` or other packages, after `show` and `hide`.
3. **The public members** of every exported class, mixin, enum, extension and extension type.

Left out are private names, declarations annotated with `@internal` or `@visibleForTesting`, and any library or
annotation you configure. See [API configuration](API-Configuration.md).

## What a change looks like

When the API changes, a normal build logs the difference and updates the file:

```text
W inspectra:api on $package$:
  The public API changed; review and commit api/shapes.api:
  @@ -26,5 +26,5 @@
     bool operator ==(Object other);
     int compareTo(Shape other);
  -  abstract Shape scale(double factor);
  +  abstract Shape scale(double factor, {bool keepLabel = true});
     @Deprecated double surface();
   }
```

`--only-check` logs the same diff and fails instead of writing. See [Reading the diff](API-Diff.md).

## Which changes break consumers

The dump records everything that can break a consumer's build, and some changes that cannot. Whether a line in the
diff is breaking depends on the direction:

| Change in the dump | Breaking? |
|:--|:--|
| A declaration or member removed | Yes |
| A parameter added, required | Yes |
| A parameter added, optional | No for callers; yes for classes that implement or override it |
| A return type narrowed (`num` → `int`) | No for callers; yes for overriders |
| A parameter type widened (`int` → `num`) | No for callers; yes for overriders |
| `abstract`, `final`, `base`, `sealed`, `interface` added to a class | Yes for subclasses and implementers |
| A default value changed | Not a compile error, but a behaviour change for every caller relying on it |
| A constant's value changed | Breaks constant expressions and `switch` patterns using it |
| A declaration or member added | No - unless consumers implement the class |

Use the diff to decide the next version: anything breaking is a major version under semantic versioning, or a minor
version before 1.0.0. `dart run %package% api semver` makes that decision for you: it compares the code with the dump
committed at the last release tag, classifies every change, and fails when the version in `pubspec.yaml` is too low.
See [Semantic versioning](API-Semver.md).

## Builder or command line

| | `build_runner` | Command line |
|:--|:--|:--|
| Write the dump | `dart run build_runner build` | `dart run %package% api dump` |
| Check the dump | `dart run build_runner build --only-check` | `dart run %package% api check` |
| Resolver | `build_runner`'s analyzer | `AnalysisContextCollection` |
| Output | Identical | Identical |

Both render with the same code, so they never disagree. See [Workflow](API-Workflow.md).

<seealso>
    <category ref="api">
        <a href="API-Workflow.md">Workflow</a>
        <a href="API-Dump-Format.md">Dump format</a>
        <a href="API-Diff.md">Reading the diff</a>
        <a href="API-Semver.md">Semantic versioning</a>
        <a href="API-Configuration.md">Configuration</a>
    </category>
    <category ref="external">
        <a href="https://dart.dev/tools/pub/versioning">Package versioning</a>
        <a href="https://dart.dev/tools/pub/package-layout#implementation-files">Implementation files</a>
    </category>
</seealso>
