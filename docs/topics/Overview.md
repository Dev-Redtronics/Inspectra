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

%product% is a dev dependency for Dart and Flutter packages that answers six questions on every build and in
every CI run:

1. **Is the code formatted, free of analyzer findings, and does it follow the team's rules?**
2. **Can I trust my dependencies?** A package with a known vulnerability, a typosquat, a name that collides with a
   private package, or a release whose source does something it should not.
3. **Is anything unsafe in this repository?** A credential pasted into a source file, a dependency with a
   published vulnerability, a dependency whose license you may not ship.
4. **Did the public API change, and did somebody mean to change it?**
5. **Is the code tested well enough to merge?**
6. **What changed since the last release, and is it documented?**

It answers them with supply-chain commands that work without configuration, seven package checks, each of which you
enable on its own, and a changelog generator.

## Features

<deflist type="wide">
    <def title="Supply-chain security" id="feature-supply-chain">
        <code>inspectra scan</code>, the default command, audits <code>pubspec.lock</code> against OSV.dev, checks
        <code>pubspec.yaml</code> for risky sources, typosquatting and dependency confusion, and runs a Trivy filesystem
        scan. <code>audit</code>, <code>inspect</code>, <code>trust</code>, <code>typosquat</code>, <code>add</code> and
        <code>hook</code> run each part on its own, vet a package before you add it, and guard commits. They keep the
        commands, flags, rule ids, JSON fields and exit codes of <code>dart_audit</code>. See the
        <a href="CLI-Reference.md#scan">command line reference</a>.
    </def>
    <def title="Format check" id="feature-format">
        <code>dart format</code> over every Dart file of the package, generated code left out, failing on any
        unformatted file - or formatting them with <code>--fix</code>. See <a href="Format-Check.md">Format
        check</a>.
    </def>
    <def title="Lint check" id="feature-lint">
        <code>dart analyze</code> with the rules of your <code>analysis_options.yaml</code>, failing from a severity
        you choose, with <code>--fix</code> running <code>dart fix --apply</code>. %product% also ships a strict
        <a href="Lint-Preset.md">lint preset</a>. See <a href="Lint-Check.md">Lint check</a>.
    </def>
    <def title="Style check" id="feature-style">
        Rules no lint covers - a license header from a template, one (public) type per file named after it,
        documentation on public and private declarations, no comments, no <code>else</code>, no
        <code>default</code> case - in the presets <code>recommended</code> and <code>strict</code>, with inline exceptions and SARIF output. Your own
        rules are Dart classes against the analyzer's syntax tree. See <a href="Style-Check.md">Style check</a> and
        <a href="Style-Custom-Rules.md">Custom style rules</a>.
    </def>
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
    <def title="Changelog" id="feature-changelog">
        Generates the changelog of the next release from Conventional Commits in the Keep a Changelog layout,
        suggests the next semantic version, checks that <code>CHANGELOG.md</code> documents the version of
        <code>pubspec.yaml</code>, and prints the release notes of a version. See
        <a href="Changelog-Overview.md">Changelog</a>.
    </def>
</deflist>

## Two ways to run the same checks

%product% plugs into `build_runner` and also ships a command line. Both read the same configuration and run the same
code; they differ in when they run and what they can see.

| | `dart run build_runner build` | `dart run inspectra …` |
|:--|:--|:--|
| When | Every build, and continuously with `watch` | When you or CI call it |
| Format check | When `run_on_build: true` | `format`, `format --fix` |
| Lint check | When `run_on_build: true` | `lint`, `lint --fix` |
| Style check | When `run_on_build: true` | `style` |
| API dump | Written to the package path; `--only-check` verifies it | `api dump` writes it, `api check` verifies it |
| Secret scan | On by default, over the <tooltip term="build source">build sources</tooltip> | Over the files on disk |
| License scan | When `run_on_build: true` | Always available |
| Vulnerability scan | When `run_on_build: true` | Always available |
| Filesystem scan | Not available | Always available |
| Coverage gate | Not available | `coverage` and `check` |
| Changelog | Not available | `changelog generate`, `changelog check` and `check`, `changelog notes` |
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
        A package that configures nothing gets no package scans, no dump and no gate. Each package check has an
        <code>enabled</code> switch that defaults to <code>false</code>, and enabling one never enables another. The
        supply-chain commands only run when you call them, and need no configuration.
    </def>
    <def title="Only the Dart toolchain and Trivy" id="principle-dependencies">
        %product% depends on <code>analyzer</code> for the API dump, <code>build</code> for the builders and
        <code>coverage</code> for the gate. <code>args</code>, <code>glob</code>, <code>path</code> and
        <code>yaml</code> are already dependencies of those; <code>archive</code>, <code>crypto</code> and
        <code>pub_semver</code> read archives, verify checksums and compare versions. HTTP uses
        <code>dart:io</code>. Everything else is done by Trivy, by the <code>git</code> command line or by the SDK's
        own tools: <code>dart format</code>, <code>dart analyze</code>, <code>dart fix</code> and
        <code>dart test</code>.
    </def>
    <def title="A typo is an error, not a silent no-op" id="principle-strict">
        Every key of the configuration is validated. An unknown key or a value of the wrong type fails with the full
        path of the key, for example <code>inspectra.trivy.secrets</code>, instead of a scan that quietly never runs.
        See <a href="Configuration-Overview.md#validation">Validation</a>.
    </def>
    <def title="A finding is not an error, and an error is not a finding" id="principle-exit-codes">
        A scan that finds something exits with 1; a check that cannot complete - Trivy not installed or crashed,
        OSV.dev unreachable, no network - exits with 69 and says so, and <code>--exit-zero</code> never hides it. A
        broken scanner can never look like a clean result. See
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

- **Not a linter of its own.** The lint check enforces the analyzer and the rules in `analysis_options.yaml`; it adds
  no rules beyond the [preset](Lint-Preset.md) you can choose to include.
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
