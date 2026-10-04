# Getting started

<primary-label ref="guide"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter,procedure" depth="2"/>

<link-summary>Add the dev dependency, enable the features, run the first build and wire up CI.</link-summary>

<card-summary>From an empty pubspec section to a package that checks itself, in six steps.</card-summary>

<tldr>
<p><b>Install</b>: <code>dart pub add dev:%package% dev:build_runner</code></p>
<p><b>Configure</b>: an <code>%pubspec_key%:</code> section in <code>pubspec.yaml</code></p>
<p><b>Run</b>: <code>dart run build_runner build</code> locally, <code>dart run %package% check</code> in CI</p>
<p><b>Requires</b>: Dart %min_dart%+, and Trivy for the scans</p>
</tldr>

This guide takes an existing Dart or Flutter package and gets every %product% feature configured and verified. Each
step works on its own: stop after any of them and you have a working setup for the features enabled so far.

## Before you start

<deflist type="medium">
    <def title="Dart %min_dart% or later">
        Check with <code>dart --version</code>. Flutter users get it with Flutter's bundled Dart.
    </def>
    <def title="A resolved package">
        Run <code>dart pub get</code> once. The license scan and the coverage gate read
        <code>.dart_tool/package_config.json</code>, and the vulnerability scan reads <code>pubspec.lock</code>.
    </def>
    <def title="Trivy, for the scans">
        Any recent version; %product% is tested with Trivy %tested_trivy%. The API dump and the coverage gate do not
        need it. See <a href="Trivy-Installation.md">Installing Trivy</a>.
    </def>
</deflist>

## Step 1: Add the dev dependency

<include from="lib.topic" element-id="install"/>

<include from="lib.topic" element-id="opt-in-note"/>

## Step 2: Check formatting and lints

<procedure title="Enable the format and lint checks" id="enable-quality">
    <step>
        <p>Optionally adopt %product%'s strict rule set in <code>analysis_options.yaml</code> - see
            <a href="Lint-Preset.md">Lint preset</a>:</p>
        <code-block lang="yaml"><![CDATA[
include: package:inspectra/lints/strict.yaml
]]></code-block>
    </step>
    <step>
        <p>Enable both checks:</p>
        <code-block lang="yaml"><![CDATA[
inspectra:
  format:
    enabled: true
  lint:
    enabled: true
]]></code-block>
    </step>
    <step>
        <p>Run them, and let the tools fix what they can:</p>
        <code-block lang="bash"><![CDATA[
dart run inspectra format --fix
dart run inspectra lint --fix
dart run inspectra lint
]]></code-block>
    </step>
    <step>
        <p>Optionally run both on every build with <code>run_on_build: true</code>.</p>
    </step>
</procedure>

## Step 3: Record the public API

<procedure title="Enable the API dump" id="enable-api">
    <step>
        <p>Add the section to <code>pubspec.yaml</code>:</p>
        <code-block lang="yaml"><![CDATA[
            inspectra:
              api:
                enabled: true
        ]]></code-block>
    </step>
    <step>
        <p>Build:</p>
        <code-block lang="bash"><![CDATA[
            dart run build_runner build
        ]]></code-block>
        <p>The build writes <code>api/&lt;package&gt;.api</code>. With <code>--verbose</code>, the log says <i>Recording the public API in api/&lt;package&gt;.api for the first time.</i></p>
    </step>
    <step>
        <p>Read <code>api/&lt;package&gt;.api</code>. It lists every declaration a consumer can use. If it holds
            something that should not be public, move it to <code>lib/src</code> or annotate it with
            <code>@internal</code> - see <a href="API-Configuration.md">API configuration</a>.</p>
    </step>
    <step>
        <p>Commit the dump. From now on, every build updates it and logs the change as a diff.</p>
    </step>
</procedure>

## Step 4: Turn on the scans

<procedure title="Enable the Trivy scans" id="enable-trivy">
    <step>
        <p>Install Trivy and check that %product% can find it:</p>
        <code-block lang="bash"><![CDATA[
            trivy --version
        ]]></code-block>
    </step>
    <step>
        <p>Enable the scans:</p>
        <code-block lang="yaml"><![CDATA[
            inspectra:
              api:
                enabled: true
              trivy:
                enabled: true
        ]]></code-block>
        <p>That enables the secret, license and vulnerability scans. The secret scan now runs on every build; the
            other two run from the command line.</p>
    </step>
    <step>
        <p>Run all scans once:</p>
        <code-block lang="bash"><![CDATA[
            dart run inspectra trivy
        ]]></code-block>
        <code-block lang="text"><![CDATA[
            Trivy secret scan: no findings.
            Trivy license scan: no findings.
            Trivy vulnerability scan: no findings.
        ]]></code-block>
        <p>The first vulnerability scan downloads the <tooltip term="Trivy database">Trivy database</tooltip>, which
            takes a few seconds; later runs reuse it.</p>
    </step>
    <step>
        <p>Optionally copy a <code>%secret_config%</code> into the package root to add your own secret rules - see
            <a href="Trivy-Secret-Rules.md">Secret rules</a>.</p>
    </step>
</procedure>

## Step 5: Add the coverage gate

<procedure title="Measure, then gate" id="enable-coverage">
    <step>
        <p>Enable coverage without a threshold, and measure:</p>
        <code-block lang="yaml"><![CDATA[
            inspectra:
              coverage:
                enabled: true
        ]]></code-block>
        <code-block lang="bash"><![CDATA[
            dart run inspectra coverage
        ]]></code-block>
    </step>
    <step>
        <p>Read the table it prints, and look at the files listed as <i>not loaded by any test</i>.</p>
    </step>
    <step>
        <p>Set a threshold at or slightly below what you measured:</p>
        <code-block lang="yaml"><![CDATA[
            inspectra:
              coverage:
                enabled: true
                min_line_coverage: 80
        ]]></code-block>
    </step>
</procedure>

<tip>
There is no default threshold on purpose. A threshold picked before measuring is either so low it never fails or so
high it fails on day one and gets switched off.
</tip>

## Step 6: Check everything in CI

Two commands cover every feature:

```bash
dart run build_runner build --only-check   # the API dump is up to date; scans enabled on build
dart run inspectra check                   # format, lint, API, all enabled scans, coverage
```

[CI integration](CI-Integration.md) has complete GitHub Actions and GitLab CI pipelines, including Trivy installation
and database caching.

## The complete configuration

```yaml
name: my_package
# ...

dev_dependencies:
  build_runner: ^%min_build_runner%
  %package%: ^%version%

%pubspec_key%:
  format:
    enabled: true
  lint:
    enabled: true
  api:
    enabled: true
  trivy:
    enabled: true
  coverage:
    enabled: true
    min_line_coverage: 80
```

```yaml
# analysis_options.yaml
include: package:inspectra/lints/strict.yaml
```

Every option not listed keeps its default. The [configuration reference](Configuration-Reference.md) lists all of
them.

<seealso>
    <category ref="start">
        <a href="Overview.md">Overview</a>
        <a href="How-It-Works.md">How it works</a>
    </category>
    <category ref="config">
        <a href="Configuration-Overview.md">Where the configuration lives</a>
        <a href="Configuration-Reference.md">Configuration reference</a>
    </category>
    <category ref="operations">
        <a href="CI-Integration.md">CI integration</a>
        <a href="Troubleshooting.md">Troubleshooting</a>
    </category>
</seealso>
