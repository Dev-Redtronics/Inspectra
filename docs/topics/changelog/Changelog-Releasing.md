# Releasing

<primary-label ref="guide"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>A release from start to finish: generate the changelog, bump the version, tag, check in CI and publish the release notes.</link-summary>

<card-summary>The release workflow with a generated changelog, and the CI jobs that keep it honest.</card-summary>

This guide walks through a release of a package whose commits follow
[Conventional Commits](Changelog-Commit-Conventions.md) and whose releases are tagged `v<version>`.

## The release

<procedure title="Release version 1.2.0" id="release">
    <step>
        <p>Make sure the tags are present locally, then preview the release:</p>
        <code-block lang="bash"><![CDATA[
git fetch --tags
dart run inspectra changelog generate
]]></code-block>
        <code-block lang="text"><![CDATA[
Version 1.2.0: 5 changes since v1.1.0, a minor release.
pubspec.yaml declares version 1.1.0; set it to 1.2.0 before tagging v1.2.0.
## 1.2.0 - 2026-10-04
...
]]></code-block>
    </step>
    <step>
        <p>Write it into <code>CHANGELOG.md</code>. To release another version than the suggested one, pass it; to
            date the release, pass the date:</p>
        <code-block lang="bash"><![CDATA[
dart run inspectra changelog generate --write
dart run inspectra changelog generate --write --release 2.0.0 --date 2026-10-05
]]></code-block>
    </step>
    <step>
        <p>Review the section. It is ordinary Markdown: reword entries, merge related ones, add an introduction or
            upgrade notes. %product% never rewrites a section once it is in the file.</p>
    </step>
    <step>
        <p>Set <code>version: 1.2.0</code> in <code>pubspec.yaml</code> and confirm that both agree:</p>
        <code-block lang="bash"><![CDATA[
dart run inspectra changelog check
]]></code-block>
        <code-block lang="text"><![CDATA[
CHANGELOG.md is well-formed and documents version 1.2.0.
]]></code-block>
    </step>
    <step>
        <p>With an <a href="API-Semver.md">API dump</a>, confirm that the version also matches the API changes since
            the last release:</p>
        <code-block lang="bash"><![CDATA[
dart run inspectra api semver
]]></code-block>
    </step>
    <step>
        <p>Commit, tag and push:</p>
        <code-block lang="bash"><![CDATA[
git commit -am "chore: release 1.2.0"
git tag v1.2.0
git push origin main v1.2.0
]]></code-block>
    </step>
</procedure>

A `chore:` commit is hidden, so the release commit itself never appears in the next changelog.

### With an Unreleased section {id="unreleased"}

If you collect notes by hand under `## Unreleased`, keep doing so: the generated section is inserted *below* it, so
your notes stay where they are. Move what belongs to the release into the new section while you review it.
`changelog check` requires `Unreleased` to be the first section.

## What changelog check validates {id="check"}

| Rule | Problem reported |
|:--|:--|
| The file exists | `The changelog does not exist.` |
| Every level two heading is a release or `Unreleased` | `"## Notes" is not a release heading. …` |
| Versions are semantic versions | `"1.0" is not a semantic version such as 1.2.3.` |
| Dates are real dates in the form `YYYY-MM-DD` | `"2026-02-30" is not a date in the form YYYY-MM-DD.` |
| Every version is listed once | `Version 1.0.0 is listed more than once.` |
| The newest release comes first | `Version 1.0.1 is listed below the lower version 1.0.0; …` |
| `Unreleased` comes first | `The "Unreleased" section must come first.` |
| The version of `pubspec.yaml` has a section | `Version 1.2.0 of pubspec.yaml has no section. …` |
| That section is not empty | `The section of version 1.2.0 is empty.` |

Each problem is printed with its line where it has one, such as `CHANGELOG.md:12: …`, and the check exits with `1`. A package without
a `version` in `pubspec.yaml` is only checked for its format.

The accepted headings are those of Keep a Changelog and of pub.dev: `## 1.2.0`, `## [1.2.0]`, `## v1.2.0`,
`## [1.2.0](https://…)`, each optionally followed by ` - 2026-10-04` or ` (2026-10-04)` and ` [YANKED]`, and
`## Unreleased` or `## [Unreleased]`. Headings inside fenced code blocks are ignored.

## In CI {id="ci"}

### Check every change

With `changelog.enabled: true`, `dart run inspectra check` includes the changelog check, so a pull request that bumps
the version without documenting it fails:

```yaml
inspectra:
  changelog:
    enabled: true
```

The check reads only files, so it needs neither Git history nor network access.

### Generate in CI

`changelog generate` needs the history and the tags. `actions/checkout` fetches a single commit by default; ask for
everything:

```yaml
- uses: actions/checkout@v7
  with:
    fetch-depth: 0

- name: Preview the next release
  run: dart run inspectra changelog generate --format json --output changelog.json
```

The JSON report holds the version, the tags, the bump, every entry by section and the Markdown:

```json
{
  "schemaVersion": 1,
  "command": "changelog generate",
  "version": "1.2.0",
  "tag": "v1.2.0",
  "previous_tag": "v1.1.0",
  "bump": "minor",
  "date": "2026-10-04",
  "changes": {
    "breaking": [],
    "sections": {
      "added": [{ "hash": "1a2b3c4…", "scope": "trivy", "description": "scan container images" }]
    }
  },
  "markdown": "## 1.2.0 - 2026-10-04\n…",
  "written": null,
  "findings": []
}
```

`version`, `tag` and `markdown` are `null` when there is nothing to release.

### Publish the release notes {id="release-notes"}

When a tag is pushed, take the description of the GitHub release from `CHANGELOG.md`. The job fails when the tagged
version is not documented:

```yaml
on:
  push:
    tags: ['v*']

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v7
      - uses: dart-lang/setup-dart@v1
      - run: dart pub get
      - name: Release notes
        run: dart run inspectra changelog notes "${GITHUB_REF_NAME#v}" --output RELEASE_NOTES.md
      - uses: softprops/action-gh-release@v3
        with:
          body_path: RELEASE_NOTES.md
```

GitLab CI works the same way with `$CI_COMMIT_TAG`:

```yaml
release:
  image: dart:stable
  rules:
    - if: $CI_COMMIT_TAG =~ /^v/
  script:
    - dart pub get
    - dart run inspectra changelog notes "${CI_COMMIT_TAG#v}" --output RELEASE_NOTES.md
  release:
    tag_name: $CI_COMMIT_TAG
    description: ./RELEASE_NOTES.md
```

%product% releases itself this way; see [Inspectra on itself](Inspectra-On-Itself.md#release).

<seealso>
    <category ref="release">
        <a href="Changelog-Overview.md">Changelog</a>
        <a href="Changelog-Commit-Conventions.md">Commit conventions</a>
        <a href="Changelog-Configuration.md">Configuration</a>
    </category>
    <category ref="operations">
        <a href="CI-Integration.md">CI integration</a>
        <a href="Troubleshooting.md#changelog">Troubleshooting</a>
    </category>
</seealso>
