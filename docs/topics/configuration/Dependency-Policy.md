# Dependency policy

<primary-label ref="cli"/>
<secondary-label ref="no-network"/>
<secondary-label ref="opt-in"/>
<secondary-label ref="since-1-1"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Organisation-wide rules for the dependencies of every package: denied and allowed packages, registries, upper bounds, SDK minimums, publishing, lockfile hygiene and unused dependencies, with automatic fixes.</link-summary>

<card-summary>Denied packages, approved registries, upper bounds, SDK minimums, publish_to, lockfile hygiene and unused dependencies - checked by deps, scan and check, fixed by deps --fix.</card-summary>

<tldr>
<p><b>Enable</b>: <code>dependency_policy: { enabled: true, … }</code>, then configure the rules you want</p>
<p><b>Check</b>: <code>dart run %package% deps</code> - offline, fast; <code>-r</code> for every package of a workspace</p>
<p><b>Fix</b>: <code>dart run %package% deps --fix</code> keeps comments and formatting</p>
<p><b>Also in</b>: <code>scan</code> and <code>check</code></p>
</tldr>

Rules for dependencies usually live in a wiki page, a spreadsheet of approved packages and review comments: no
abandoned packages, only the internal registry, no unbounded constraints, test packages out of the runtime
dependencies. And the most expensive mistake costs one command: an internal package without `publish_to: none` is
uploaded to pub.dev by `dart pub publish`. The dependency policy turns these rules into configuration that every
package checks the same way, locally, in the pre-merge pipeline and in the nightly scan.

## Enabling the policy {id="enable"}

```yaml
inspectra:
  dependency_policy:
    enabled: true
    denied:
      - name: http_parser_legacy
        reason: Unmaintained since 2023.
        replacement: http
    allowed_hosts: [https://pub.acme.corp, https://pub.dev]
    require_upper_bound: true
    min_sdk: 3.6.0
    dev_only: [mockito, build_runner, lints, test]
    require_publish_to: true
    published_packages: [acme_public_sdk]
    lockfile_in_sync: true
```

Every rule is off until it is configured, and nothing is checked until `enabled` is set, so updating %product% never
adds findings on its own. The findings are of the source `pubspec` and behave like every other finding: `ignore`
rules with a reason, the [baseline](Baseline.md) (scope `scan`), `--fail-on`, and JSON, SARIF and Markdown output.

## Rules {id="rules"}

| Rule | Severity | Configured by | Reported when | `--fix` |
|:--|:--|:--|:--|:--|
| `DENIED_PACKAGE` | high | `denied` | A denied package is declared, or pulled in transitively according to `pubspec.lock` | - |
| `PACKAGE_NOT_ALLOWED` | high | `allowed` | A hosted dependency is not on the allowed list | - |
| `DISALLOWED_HOST` | high | `allowed_hosts`, `allowed_git_hosts` | A package comes from another registry or Git host, directly or transitively | - |
| `MISSING_UPPER_BOUND` | medium | `require_upper_bound` | A hosted constraint has no upper bound, such as `>=1.2.0` | `^1.2.0` |
| `SDK_BELOW_POLICY` | medium | `min_sdk`, `min_flutter` | `environment.sdk` or `environment.flutter` allows an SDK below the minimum | - |
| `DEV_ONLY_DEPENDENCY` | medium | `dev_only` | A development package is listed under `dependencies` | moved to `dev_dependencies` |
| `MISSING_PUBLISH_TO` | medium | `require_publish_to` | A package has no `publish_to` and is not one of `published_packages` | `publish_to: none` |
| `MISSING_METADATA` | low | `required_metadata` | A publishable package lacks `description`, `repository`, `homepage`, `issue_tracker`, `documentation` or `topics` | - |
| `LOCKFILE_OUT_OF_SYNC` | high | `lockfile_in_sync` | A direct dependency is missing from `pubspec.lock`, locked outside its constraint, or removed but still locked | - |
| `MISSING_CHECKSUM` | medium | `lockfile_checksums` | A hosted package of `pubspec.lock` has no `sha256` | - |
| `UNUSED_DEPENDENCY` | low | `check_imports` | No file of `lib/` or `bin/` imports a dependency; the finding says when only tests use it | - |
| `DEV_DEPENDENCY_IN_LIB` | high | `check_imports` | `lib/` or `bin/` imports a development dependency, which the package's users do not get | - |

Hosted dependencies without a `hosted:` URL come from `network.pub_hosted_url`, which defaults to `PUB_HOSTED_URL`.
`https://pub.dev` and `https://pub.dartlang.org` count as the same registry. The lockfile rules run for the package
the lockfile belongs to, so the members of a pub workspace do not report the root lockfile once each.

The import rules parse the Dart files without resolving them, so no `dart pub get` is needed. Imports, exports and
conditional imports count; nested packages such as an `example/` package with a `pubspec.yaml` of its own are left
out. Packages that are used without an import, such as `cupertino_icons` through its font, go into `unused_allow`.

## Checking {id="deps"}

```bash
dart run %package% deps            # the package in the current directory
dart run %package% deps -r         # every package below it, workspace members included
dart run %package% deps -f sarif -o deps.sarif
```

`deps` runs the built-in pubspec rules - unconstrained versions, Git branches, plain HTTP sources, overrides, old SDK
constraints - and the policy, without any network access. It is fast enough for a pre-commit hook. `scan` applies the
policy to the packages it scans, and `check` runs it as the step "Dependency policy" while `enabled` is set.

## Fixing {id="fix"}

```bash
dart run %package% deps --fix
```

`--fix` applies the three rules a tool can decide: it bounds constraints with a caret (`>=1.2.0` becomes `^1.2.0`),
moves the packages of `dev_only` to `dev_dependencies`, and adds `publish_to: none` below the package name. The file is
edited, not rewritten: comments, order, quoting and the layout of every other key stay as they are. Each change is
listed, and the remaining findings are reported as without `--fix`. Running it again changes nothing.

```text
✔ Fixed pubspec.yaml: http: >=1.2.0 -> ^1.2.0
✔ Fixed pubspec.yaml: mockito: dependencies -> dev_dependencies
✔ Fixed pubspec.yaml: publish_to: none
[HIGH]     The package left_pad is denied  (DENIED_PACKAGE)  pubspec.yaml:9
    Unmaintained. Use string_padding instead.
```

Denied packages, registries, SDK minimums and lockfiles need a decision or `dart pub get` and are never changed.

## Configuration {id="configuration"}

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | bool | `false` | Apply the policy in `scan`, `deps` and `check` |
| `denied` | list | `[]` | Entries with `name`, `reason` (required) and `replacement` |
| `allowed` | list | `[]` | When not empty, the only hosted packages that may be declared |
| `allowed_hosts` | list | `[]` | When not empty, the only registries; pub.dev is `https://pub.dev` |
| `allowed_git_hosts` | list | `[]` | When not empty, the only Git hosts, such as `git.acme.corp` |
| `require_upper_bound` | bool | `false` | Every hosted constraint needs an upper bound |
| `min_sdk`, `min_flutter` | version | unset | The lowest SDK the `environment` constraints may allow |
| `dev_only` | list | `[]` | Packages that belong in `dev_dependencies` |
| `require_publish_to` | bool | `false` | Every package needs `publish_to` |
| `published_packages` | list | `[]` | Packages meant for pub.dev, which need no `publish_to` |
| `required_metadata` | list | `[]` | Fields a publishable package must declare |
| `lockfile_in_sync` | bool | `false` | `pubspec.lock` must match the direct dependencies |
| `lockfile_checksums` | bool | `false` | Every hosted package of `pubspec.lock` needs a `sha256` |
| `check_imports` | bool | `false` | Report unused dependencies and development dependencies used by `lib/` |
| `unused_allow` | list | `[cupertino_icons]` | Packages never reported as unused |

Shared across an organisation, the section is the same in every repository; until central policies arrive, keep it in
a template repository and check it with `inspectra config lint` and the [JSON Schema](Configuration-Tools.md#schema).

<seealso>
    <category ref="config">
        <a href="Configuration-Reference.md#dependency_policy">Configuration reference</a>
        <a href="Baseline.md">Baseline</a>
        <a href="Configuration-Tools.md">Configuration tools</a>
    </category>
    <category ref="reference">
        <a href="CLI-Reference.md#deps">deps</a>
    </category>
    <category ref="external">
        <a href="https://dart.dev/tools/pub/dependencies">Package dependencies</a>
        <a href="https://dart.dev/tools/pub/pubspec#publish_to">publish_to</a>
    </category>
</seealso>
