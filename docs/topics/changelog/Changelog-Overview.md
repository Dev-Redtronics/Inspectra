# Changelog

<primary-label ref="cli"/>
<secondary-label ref="cli-only"/>
<secondary-label ref="no-network"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Generate the changelog of the next release from Conventional Commits, check it in CI and publish it as release notes.</link-summary>

<card-summary>CHANGELOG.md from your Git history: Keep a Changelog sections, a suggested semantic version, a CI check and release notes.</card-summary>

<tldr>
<p><b>Generate</b>: <code>dart run %package% changelog generate</code>, add it with <code>--write</code></p>
<p><b>Check</b>: <code>dart run %package% changelog check</code>, or <code>changelog: { enabled: true }</code> for <code>check</code></p>
<p><b>Release notes</b>: <code>dart run %package% changelog notes 1.2.0</code></p>
<p><b>Needs</b>: <code>git</code>, commits that follow Conventional Commits, release tags such as <code>v1.2.0</code></p>
</tldr>

A changelog tells the users of a package what changed and whether an upgrade is safe. Written by hand, it is written
last, under time pressure, and from memory. Yet the information is already in the repository: every commit says what
it changed, and when the commits follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/), they
also say what kind of change it was.

%product% turns that history into a changelog in the
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) layout that pub.dev displays:

```markdown
## 1.2.0 - 2026-10-04

### Breaking changes

- **cli:** rename --out to --output ([`4e1d2c9`](https://github.com/acme/demo/commit/4e1d2c9…))

  Scripts that pass --out must use --output.

### Added

- **trivy:** scan container images ([`1a2b3c4`](https://github.com/acme/demo/commit/1a2b3c4…))

### Fixed

- handle empty lockfiles ([`9f8e7d6`](https://github.com/acme/demo/commit/9f8e7d6…))

[Compare v1.1.0...v1.2.0](https://github.com/acme/demo/compare/v1.1.0...v1.2.0)
```

It reads the commits since the latest release tag, sorts them into sections, suggests the next version under
[semantic versioning](https://semver.org/), and adds the section to `CHANGELOG.md` without touching what you wrote by
hand. The generator is part of %product% itself and needs no other package: it reads the history with the `git`
command line.

## Quick start

<procedure title="Release with a generated changelog" id="first-release">
    <step>
        <p>Preview the next release:</p>
        <code-block lang="bash"><![CDATA[
dart run inspectra changelog generate
]]></code-block>
        <p>The section goes to standard output; the suggested version and why goes to standard error.</p>
    </step>
    <step>
        <p>Add it to <code>CHANGELOG.md</code>, edit it if you like, and set the same version in
            <code>pubspec.yaml</code>:</p>
        <code-block lang="bash"><![CDATA[
dart run inspectra changelog generate --write
]]></code-block>
    </step>
    <step>
        <p>Let CI check that every version is documented:</p>
        <code-block lang="yaml"><![CDATA[
inspectra:
  changelog:
    enabled: true
]]></code-block>
        <p><code>dart run inspectra check</code> now fails when <code>CHANGELOG.md</code> has no section for the
            version in <code>pubspec.yaml</code>.</p>
    </step>
    <step>
        <p>Commit, tag the release and use its section as release notes:</p>
        <code-block lang="bash"><![CDATA[
git tag v1.2.0
dart run inspectra changelog notes 1.2.0 --output RELEASE_NOTES.md
]]></code-block>
    </step>
</procedure>

## The three commands

| Command | Reads | Does | Fails with |
|:--|:--|:--|:--|
| [`changelog generate`](CLI-Reference.md#changelog-generate) | Git history, `pubspec.yaml` | Prints the section of the next release; adds it with `--write` | `64` for a bad revision, version or date, or outside a Git repository; `69` without Git |
| [`changelog check`](CLI-Reference.md#changelog-check) | `CHANGELOG.md`, `pubspec.yaml` | Validates the file and that the package version is documented | `1` for every problem found |
| [`changelog notes`](CLI-Reference.md#changelog-notes) | `CHANGELOG.md` | Prints the section of one release | `65` when the release is missing or empty |

`generate` and `notes` support `--format json` and `--output` like every other command. `check` runs on its own and,
with `changelog.enabled`, as a step of `inspectra check`.

## What it guarantees

<deflist type="medium">
    <def title="Your text stays yours" id="guarantee-manual-text">
        <code>--write</code> inserts a new section above the newest release and below the introduction and an
        <code>Unreleased</code> section. It never rewrites existing sections, keeps the file's line endings, and
        refuses to document a version twice.
    </def>
    <def title="No surprise versions" id="guarantee-version">
        The suggested version follows from the commits; a higher version you already set in
        <code>pubspec.yaml</code> wins, and <code>--release</code> overrides both. See
        <a href="Changelog-Commit-Conventions.md#versions">Versions</a>.
    </def>
    <def title="Commit messages are untrusted text" id="guarantee-sanitised">
        Control characters, terminal escape sequences, bidirectional overrides and invisible characters in commit
        messages are written as visible <code>\u{XXXX}</code> notation, so that a changelog cannot hide or reorder
        text. Links are only built from an <code>https://</code> or <code>http://</code> repository URL.
    </def>
    <def title="Offline and read-only towards Git" id="guarantee-offline">
        %product% runs <code>git log</code>, <code>git tag --list</code> and <code>git rev-parse</code> only. It
        never fetches, commits or tags.
    </def>
</deflist>

<seealso>
    <category ref="release">
        <a href="Changelog-Commit-Conventions.md">Commit conventions</a>
        <a href="Changelog-Releasing.md">Releasing</a>
        <a href="Changelog-Configuration.md">Configuration</a>
    </category>
    <category ref="external">
        <a href="https://www.conventionalcommits.org/en/v1.0.0/">Conventional Commits 1.0.0</a>
        <a href="https://keepachangelog.com/en/1.1.0/">Keep a Changelog 1.1.0</a>
        <a href="https://dart.dev/tools/pub/versioning">Package versioning</a>
    </category>
</seealso>
