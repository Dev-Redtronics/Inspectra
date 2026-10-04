# Changelog configuration

<primary-label ref="config"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Every option of the changelog: section of the configuration, its default and what it does.</link-summary>

<card-summary>The changelog file, the tag prefix, the section of each commit type and the link templates.</card-summary>

The `changelog:` section configures all three changelog commands. Like every section, it lives in the `inspectra:`
section of `pubspec.yaml` or in `inspectra.yaml`, and every key can be overridden with `--set` or an `INSPECTRA_*`
environment variable. See [Where the configuration lives](Configuration-Overview.md).

Generating a changelog needs no configuration at all. The only switch is `enabled`, which adds the changelog check to
`inspectra check`.

```yaml
inspectra:
  changelog:
    enabled: false
    file: CHANGELOG.md
    tag_prefix: v
    types:
      feat: added
      fix: fixed
      perf: changed
      refactor: changed
      revert: changed
      deprecate: deprecated
      remove: removed
      security: security
      docs: hidden
      style: hidden
      test: hidden
      build: hidden
      ci: hidden
      chore: hidden
    unconventional: hidden
    # repository: https://github.com/acme/demo
    commit_url: '{repository}/commit/{hash}'
    compare_url: '{repository}/compare/{from}...{to}'
```

## Options

| Option | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | bool | `false` | Whether [`inspectra check`](CLI-Reference.md#check) runs the changelog check. `changelog check` runs either way. |
| `file` | path | `CHANGELOG.md` | The changelog, relative to the package root. |
| `tag_prefix` | string | `v` | The text before the version in release tags. `''` for tags such as `1.2.0`, `release-` for `release-1.2.0`. |
| `types` | map | see [below](#types) | The section of each Conventional Commits type. |
| `unconventional` | section | `hidden` | The section of commits that do not follow Conventional Commits. |
| `repository` | URL | `repository` of `pubspec.yaml` | The repository the links point to. Only `https://` and `http://` URLs produce links; a trailing `/` or `.git` is removed. Without one, entries show the plain short hash. |
| `commit_url` | template | `{repository}/commit/{hash}` | The link of an entry. Must contain `{hash}`. |
| `compare_url` | template | `{repository}/compare/{from}...{to}` | The comparison link at the end of a release. Must contain `{to}`; `{from}` is the previous tag. |

## types {id="types"}

A map from commit type to one of `added`, `changed`, `deprecated`, `removed`, `fixed`, `security` or `hidden`. The
keys you list replace the defaults for those types; the other defaults stay. Types that are neither listed nor among
the defaults are hidden. Breaking changes are listed whatever their type.

```yaml
inspectra:
  changelog:
    types:
      docs: changed      # document documentation changes
      deps: security     # a project specific type
      refactor: hidden   # keep refactorings out of the changelog
```

An unknown section name is an error that names the key, for example
`Invalid Inspectra configuration at "inspectra.changelog.types.feat": expected one of added, changed, …`.

## Other hosts {id="hosts"}

The default templates are those of GitHub, which Gitea and Forgejo share. For other hosts:

| Host | `commit_url` | `compare_url` |
|:--|:--|:--|
| GitLab | `{repository}/-/commit/{hash}` | `{repository}/-/compare/{from}...{to}` |
| Bitbucket | `{repository}/commits/{hash}` | `{repository}/branches/compare/{to}%0D{from}` |
| Azure DevOps | `{repository}/commit/{hash}` | `{repository}/branchCompare?baseVersion=GT{from}&targetVersion=GT{to}` |

## Overrides {id="overrides"}

```bash
dart run inspectra changelog generate --set changelog.tag_prefix=release-
INSPECTRA_CHANGELOG_FILE=doc/CHANGES.md dart run inspectra changelog notes
dart run inspectra changelog generate --set changelog.types.docs=changed
```

`--set changelog.types.<type>` works for the default types and for types listed in the file; add new types in the
file.

<seealso>
    <category ref="release">
        <a href="Changelog-Overview.md">Changelog</a>
        <a href="Changelog-Commit-Conventions.md">Commit conventions</a>
        <a href="Changelog-Releasing.md">Releasing</a>
    </category>
    <category ref="config">
        <a href="Configuration-Reference.md#changelog">Configuration reference</a>
    </category>
</seealso>
