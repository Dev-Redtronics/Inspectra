# Commit conventions

<primary-label ref="cli"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>How %product% reads Conventional Commits, which section each type goes to, and how the next version is chosen.</link-summary>

<card-summary>Types, scopes, breaking changes, reverts and the semantic version that follows from them.</card-summary>

The generator reads every commit since the previous release, skips merge commits, and parses each message according
to [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

## The commit message

```text
feat(trivy)!: scan container images

Images are scanned with the same severities as the filesystem.

BREAKING CHANGE: trivy.filesystem.scanners no longer accepts "config";
use "misconfig".
Refs: #42
```

| Part | Example | Becomes |
|:--|:--|:--|
| Type | `feat` | The section, see [below](#sections). Case does not matter. |
| Scope, optional | `(trivy)` | The bold prefix of the entry: **trivy:** |
| `!`, optional | `feat(trivy)!:` | A breaking change |
| Description | `scan container images` | The text of the entry |
| Body | `Images are scanned …` | Not shown |
| `BREAKING CHANGE:` or `BREAKING-CHANGE:` footer | `trivy.filesystem.scanners …` | A breaking change, with the footer text below the entry. The text may span several lines and ends at the next footer such as `Refs:`. |

The header must be exactly `type(scope)!: description`, with a space after the colon. Subjects such as
`Update README`, `feat:missing space`, `feat(): x` or `fixup! feat: x` are *unconventional*; they are hidden unless you
give them a section with [`unconventional`](Changelog-Configuration.md).

## Sections {id="sections"}

Each type goes to one section of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The sections appear in
this order, and empty sections are left out:

| Section | Types by default |
|:--|:--|
| Breaking changes | Every breaking change, whatever its type |
| Added | `feat` |
| Changed | `perf`, `refactor`, `revert` |
| Deprecated | `deprecate` |
| Removed | `remove` |
| Fixed | `fix` |
| Security | `security` |
| *hidden* | `docs`, `style`, `test`, `build`, `ci`, `chore`, every other type, and unconventional commits |

A breaking change is listed under **Breaking changes** only, so that nobody skims past it in another section. Map your
own types, or move the defaults, in [`changelog.types`](Changelog-Configuration.md#types).

## Reverts and duplicates {id="reverts"}

- `git revert` writes `Revert "feat(trivy): scan images"` and `This reverts commit <hash>.`. When the reverted commit
  is part of the same release, both commits are left out: neither change reaches the release. When it was released
  before, the revert is listed as `Revert "scan images"` under the section of the type `revert`.
- A conventional `revert: …` commit with a `This reverts commit <hash>.` line is handled the same way.
- The same change committed twice, for example after a cherry-pick, is listed once.

## Versions {id="versions"}

Without `--release`, the version follows from the commits and the latest release tag, as
[semantic versioning](https://semver.org/) and [Dart's versioning conventions](https://dart.dev/tools/pub/versioning)
prescribe:

| The release contains | From `1.4.2` | From `0.4.2` |
|:--|:--|:--|
| A breaking change | `2.0.0` | `0.5.0` |
| An `Added` entry | `1.5.0` | `0.4.3` |
| Anything else that is listed | `1.4.3` | `0.4.3` |

Before `1.0.0` the minor version takes the role of the major version, so a breaking change raises the minor version
and everything else the patch version. A pre-release is followed by its release: from `2.0.0-beta.1`, a breaking
change suggests `2.0.0`.

Two more rules decide the result:

1. **No release tag yet**: the version in `pubspec.yaml` is the first release. Without one, pass `--release`.
2. **`pubspec.yaml` is ahead**: when you have already set a higher version in `pubspec.yaml`, that version is used.
   When the suggested version differs from `pubspec.yaml`, %product% tells you to update it before tagging.

## Release tags {id="tags"}

The previous release is the tag with the highest semantic version among the tags that are reachable from `--to` and
start with [`tag_prefix`](Changelog-Configuration.md), `v` by default. `v1.10.0` is newer than `v1.9.0`, and a tag
that is not a semantic version after the prefix, such as `v1.9` or `nightly`, is ignored.

Pass `--from` to start at any other revision: a tag, a branch or a commit. The comparison link then starts there too.
The version is counted from `--from` when it is a release tag, and from the latest release tag otherwise.

<warning>
A shallow clone, the default of <code>actions/checkout</code>, has neither the older commits nor the tags. %product%
warns about it; fetch the whole history with <code>fetch-depth: 0</code>. See
<a href="Changelog-Releasing.md#ci">Releasing in CI</a>.
</warning>

<seealso>
    <category ref="release">
        <a href="Changelog-Overview.md">Changelog</a>
        <a href="Changelog-Releasing.md">Releasing</a>
        <a href="Changelog-Configuration.md">Configuration</a>
    </category>
    <category ref="external">
        <a href="https://www.conventionalcommits.org/en/v1.0.0/">Conventional Commits 1.0.0</a>
        <a href="https://semver.org/">Semantic Versioning</a>
    </category>
</seealso>
