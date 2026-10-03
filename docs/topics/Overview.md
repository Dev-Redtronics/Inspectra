# Overview

<primary-label ref="guide"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>What %product% does, why it exists, and the principles behind its behaviour.</link-summary>

<card-summary>Security scans, API dumps and a coverage gate for Dart, in one dev dependency.</card-summary>

<web-summary>
Inspectra adds Trivy secret, license, vulnerability and filesystem scans, a committed public API dump and a coverage
gate to Dart and Flutter packages, run by build_runner and configured in pubspec.yaml.
</web-summary>

%product% is a dev dependency for Dart and Flutter packages that answers three questions on every build and in
every CI run:

1. **Is anything unsafe in this repository?** A credential pasted into a source file, a dependency with a
   published vulnerability, a dependency whose license you may not ship.
2. **Did the public API change, and did somebody mean to change it?**
3. **Is the code tested well enough to merge?**

It answers them with three features, each of which you enable on its own.

## Features

<deflist type="wide">
    <def title="Security and compliance scans" id="feature-trivy">
        Four scans run by <a href="Trivy-Overview.md">Trivy</a>: a <a href="Trivy-Secret-Scan.md">secret scan</a>
        of your sources and configuration files, a <a href="Trivy-License-Scan.md">license scan</a> of the
        dependencies you ship, a <a href="Trivy-Vulnerability-Scan.md">vulnerability scan</a> of
        <code>pubspec.lock</code>, and a plain <a href="Trivy-Filesystem-Scan.md">filesystem scan</a> that also
        checks infrastructure files such as Dockerfiles for misconfigurations.
    </def>
    <def title="Public API validation" id="feature-api">
        A text dump of everything your <tooltip term="public library">public libraries</tooltip> export, written to
        <code>api/&lt;package&gt;.api</code> and committed. Every API change becomes a reviewable diff, and
        <code>build_runner build --only-check</code> fails in CI when the code and the dump disagree. See
        <a href="API-Overview.md">Public API validation</a>.
    </def>
    <def title="Coverage gate" id="feature-coverage">
        Runs <code>dart test --coverage</code> or <code>flutter test --coverage</code>, merges the
        <tooltip term="hit map">hit maps</tooltip> with <code>package:coverage</code>, writes
        <tooltip term="lcov">lcov.info</tooltip> and fails below a line coverage threshold. See
        <a href="Coverage-Overview.md">Coverage</a>.
    </def>
</deflist>

## Two ways to run the same checks

%product% plugs into `build_runner` and also ships a command line. Both read the same configuration and run the same
code; they differ in when they run and what they can see.

| | `dart run build_runner build` | `dart run inspectra …` |
|:--|:--|:--|
| When | Every build, and continuously with `watch` | When you or CI call it |
| API dump | Written to the package path; `--only-check` verifies it | `api dump` writes it, `api check` verifies it |
| Secret scan | On by default, over the <tooltip term="build source">build sources</tooltip> | Over the files on disk |
| License scan | When `run_on_build: true` | Always available |
| Vulnerability scan | When `run_on_build: true` | Always available |
| Filesystem scan | Not available | Always available |
| Coverage gate | Not available | `coverage` and `check` |
| Reruns | Only when a file the step read changed | Every time |

<tip>
Use the builders for fast feedback while you work, and <code>dart run inspectra check</code> plus
<code>dart run build_runner build --only-check</code> in CI. <a href="CI-Integration.md">CI integration</a> has complete
pipelines.
</tip>

## Principles

These decisions shape how every feature behaves. When something surprises you, it is probably one of them.

<deflist type="medium" collapsible="true">
    <def title="Everything is opt-in" id="principle-opt-in">
        A package that configures nothing gets no scans, no dump and no gate. Each feature has an
        <code>enabled</code> switch that defaults to <code>false</code>, and enabling one never enables another.
    </def>
    <def title="Only the Dart toolchain and Trivy" id="principle-dependencies">
        %product% depends on <code>analyzer</code> for the API dump, <code>build</code> for the builders and
        <code>coverage</code> for the gate. <code>args</code>, <code>glob</code>, <code>path</code> and
        <code>yaml</code> are already dependencies of those. Everything else is done by Trivy or by
        <code>dart test</code>.
    </def>
    <def title="A typo is an error, not a silent no-op" id="principle-strict">
        Every key of the configuration is validated. An unknown key or a value of the wrong type fails with the full
        path of the key, for example <code>inspectra.trivy.secrets</code>, instead of a scan that quietly never runs.
        See <a href="Configuration-Overview.md#validation">Validation</a>.
    </def>
    <def title="A finding is not an error, and an error is not a finding" id="principle-exit-codes">
        A scan that finds something exits with 1; Trivy failing to run - not installed, crashed, no network - exits
        with 2 and says so. A broken scanner can never look like a clean result. See
        <a href="CLI-Reference.md#exit-codes">Exit codes</a>.
    </def>
    <def title="Report what you ship" id="principle-shipped">
        The license scan checks only <tooltip term="shipped dependency">shipped dependencies</tooltip> by default,
        because a license binds what reaches a consumer. The vulnerability scan checks dev dependencies too, because a
        vulnerable build tool still runs on your machines.
    </def>
    <def title="Same input, same output" id="principle-deterministic">
        The API dump is sorted, contains no paths or timestamps, and does not change when a declaration moves between
        files under <code>lib/src</code>. Findings are sorted by severity, target and identifier.
    </def>
</deflist>

## What %product% is not

- **Not a linter.** Style and correctness checks belong in `analysis_options.yaml`; run `dart analyze` next to
  %product%.
- **Not a replacement for Trivy's own configuration.** `trivy.yaml`, `.trivyignore` and `trivy-secret.yaml` in the
  package root keep working; %product% runs Trivy in the package root so that they apply. See
  [Installing Trivy](Trivy-Installation.md#working-directory).
- **Not a binary compatibility checker.** Dart has no stable binary interface between packages; the dump records the
  source-level API, which is what breaks a consumer's build.

<seealso>
    <category ref="start">
        <a href="Getting-Started.md">Getting started</a>
        <a href="How-It-Works.md">How it works</a>
    </category>
    <category ref="reference">
        <a href="Configuration-Reference.md">Configuration reference</a>
        <a href="Compatibility.md">Compatibility</a>
    </category>
    <category ref="operations">
        <a href="Migrating-From-Kreate.md">Coming from Kreate</a>
    </category>
</seealso>
