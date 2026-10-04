# Reading the diff

<primary-label ref="builder"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>The unified diff Inspectra prints when the API changed, line by line.</link-summary>

<card-summary>Hunks, context lines and line numbers: what each part of the API diff means.</card-summary>

When the rendered API differs from the committed dump, %product% prints a unified diff - the format `git diff` uses -
from the committed dump (`-`) to the current API (`+`). The builder logs it as a warning; `api check` prints it before
failing.

```text
@@ -26,5 +26,5 @@
   bool operator ==(Object other);
   int compareTo(Shape other);
-  abstract Shape scale(double factor);
+  abstract Shape scale(double factor, {bool keepLabel = true});
   @Deprecated double surface();
 }
```

## Parts of a hunk

<deflist type="medium">
    <def title="@@ -26,5 +26,5 @@">
        The hunk header. <code>-26,5</code>: the hunk covers 5 lines of the committed dump, starting at line 26.
        <code>+26,5</code>: the same for the current API. When lines were added or removed, the counts differ.
    </def>
    <def title="Lines starting with a space">
        Context: unchanged lines around the change, two before and two after, to show where it is.
    </def>
    <def title="Lines starting with -">
        In the committed dump, not in the current API: removed or changed declarations.
    </def>
    <def title="Lines starting with +">
        In the current API, not in the committed dump: added or changed declarations.
    </def>
</deflist>

A changed line appears as a `-` line followed by a `+` line. Changes more than four lines apart get separate hunks,
so two edits at opposite ends of the dump are shown as two short hunks, not as everything in between.

## Typical patterns

<tabs group="patterns">
    <tab title="Added" group-key="added">
        <code-block lang="text"><![CDATA[
@@ -38,4 +38,6 @@
 sealed class Unit {}
 
+Shape circle(double radius);
+
 const String defaultLabel = 'shape';
 
]]></code-block>
        <p>A new top-level function, with the blank line that separates declarations. Not breaking.</p>
    </tab>
    <tab title="Removed" group-key="removed">
        <code-block lang="text"><![CDATA[
@@ -24,5 +24,4 @@
   abstract double get area;
   int get hashCode;
-  bool operator ==(Object other);
   int compareTo(Shape other);
   abstract Shape scale(double factor);
]]></code-block>
        <p>A member removed: five lines before, four after. Breaking for every caller.</p>
    </tab>
    <tab title="Changed" group-key="changed">
        <code-block lang="text"><![CDATA[
@@ -18,5 +18,5 @@
 }
 
-abstract base class Shape implements Comparable<Shape> {
+abstract final class Shape implements Comparable<Shape> {
   final String label;
   Shape(String label);
]]></code-block>
        <p>A class modifier changed from <code>base</code> to <code>final</code>. Breaking for subclasses outside the
            library.</p>
    </tab>
    <tab title="Deprecated" group-key="deprecated">
        <code-block lang="text"><![CDATA[
@@ -26,5 +26,5 @@
   bool operator ==(Object other);
   int compareTo(Shape other);
-  abstract Shape scale(double factor);
+  @Deprecated abstract Shape scale(double factor);
   @Deprecated double surface();
 }
]]></code-block>
        <p>A member deprecated. Not breaking, but worth a changelog entry.</p>
    </tab>
</tabs>

## Long diffs

At most 120 changed lines are printed; the rest is summarized as `... and N more changed line(s)`. The committed dump
and a fresh `dart run %package% api dump` in a scratch checkout give the full picture, for example with
`git diff --no-index`.

For very large dumps with changes spread throughout, the region between the first and the last change is compared
line by line only up to a size limit; beyond it, the region is shown as removed and re-added. In practice this happens
only when most of the API changed at once, such as after a mass rename.

<seealso>
    <category ref="api">
        <a href="API-Workflow.md">Workflow</a>
        <a href="API-Dump-Format.md">Dump format</a>
    </category>
</seealso>
